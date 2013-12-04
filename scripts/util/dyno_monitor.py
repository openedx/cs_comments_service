import json
import logging
import math
import multiprocessing
import os
import Queue
import random
import re
import sys
import time

import heroku


#
# constants
#

# minimum number of dynos in formation for a valid analysis
# this is used sanity-check configuration before doing anything else
MIN_DYNOS = 5

# minimum number of seconds for which a dyno must have been "up"
# prior to capturing timings, else we disregard it.
MIN_UPTIME = 60


#
# defaults
# these settings can be overridden using command-line options
#

# minimum and maximum number of seconds to capture timings from logs
DEFAULT_MIN_TIMING_WINDOW = 60
DEFAULT_MAX_TIMING_WINDOW = 120

# minimum number of data points per dyno
DEFAULT_MIN_TIMINGS = 32

# number of stddevs from the the mean for slow dyno detection
DEFAULT_KILL_THRESHOLD = 2

# minimum average response time for a slow dyno (prevent false positives)
DEFAULT_MIN_THRESHOLD = 0.2


#
# utilities
#

def average(s):
    return sum(s) * 1.0 / len(s)

def variance(s): 
    avg = average(s)
    return map(lambda x: (x - avg)**2, s)

def stddev(s):
    return math.sqrt(average(variance(s)))


class DynoTimings(dict):

    line_regex = r'app\[(?P<dyno>web\.[0-9]+)\].*(?P<status>[0-9]{3}) (?P<bytes>[0-9]+) (?P<seconds>[0-9\.]+)$'

    def parse_line(self, line):
        m = re.search(self.line_regex, line)
        if m:
            d = m.groupdict()
            dyno = d['dyno']
            seconds = float(d['seconds'])
            self.setdefault(dyno, []).append(seconds)

    def averages(self):
        return dict((dyno, average(self[dyno])) for dyno in self
                            if len(self[dyno]) > settings['min_timings'])

    def counts(self):
        return dict((dyno, len(self[dyno])) for dyno in self)

    @property
    def slow_threshold(self):
        dyno_averages = self.averages().values()
        return average(dyno_averages) + (3 * stddev(dyno_averages))


def alert(msg):
    """
    we found a problem.  msg indicates what.

    this should trigger an alert.
    """
    logging.warn(msg)
    return 2


def abort(msg):
    """
    the script itself failed to complete.  msg indicates why.

    this should trigger an alert.
    """
    logging.error(msg)
    return 1


def skip(msg):
    """
    the script won't do anything, but there's no reason for concern.

    this should log, but not alert.
    """
    logging.info(msg)
    return 0


def main(app, settings):

    #
    # setup / sanity check
    #

    # ensure enough dynos in the formation for a valid response time analysis
    # if not, this constitutes a configuration error - either more dynos
    # should be up, or this script should not be running
    num_dynos = len(list(app.processes['web']))
    if num_dynos < MIN_DYNOS:
        msg = 'not enough dynos in this formation ({} < {})'
        return abort(msg.format(num_dynos, MIN_DYNOS))

    # make sure settings are sane
    msg = None
    if not settings['max_window'] >= settings['min_window']:
        msg = 'invalid timing window (max:{max_window} < min:{min_window})'
    else:
        for k in ('min_window', 'min_timings', 'min_threshold', 'kill_threshold'):
            if not settings[k] > 0:
                msg = 'invalid setting for {k}: 0 > {{{k}}}'.format(k=k)
                break
    if msg:
        return abort(msg.format(**settings))

    logging.info(json.dumps(settings))


    #
    # capture
    #

    def process_app_logs(app, queue):
        for line in app.logs(source="app", ps="web", tail=True):
            queue.put(line)

    timings = DynoTimings()

    llq = multiprocessing.Queue()
    p = multiprocessing.Process(target=process_app_logs, args=(app, llq))
    p.start()

    try:
        start_time = time.time()
        min_stop_time = start_time + settings['min_window']
        max_stop_time = start_time + settings['max_window']

        while True:
            t = time.time()
            # regardless of how much data was captured,
            # hard stop when the max timing window has elapsed
            remaining_time = max_stop_time - t
            if remaining_time <= 0:
                # stop the log-reader process, but don't break the loop yet,
                # might have more queued data to ingest.
                if p.is_alive():
                    p.terminate()
            try:
                line = llq.get(timeout=remaining_time + 1)
                timings.parse_line(line)
            except Queue.Empty:
                break
            # we can stop now if the minimum timing window has elapsed *and* we
            # have enough data
            if t >= min_stop_time and min(timings.counts().values()) >= settings['min_timings']:
                break

    finally:
        # make sure subprocess is cleaned up before continuing...
        if p.is_alive():
            p.terminate()

    elapsed_time = time.time() - start_time
    total_timings = sum([len(v) for v in timings.values()])
    msg = json.dumps({
        'timed_dynos': len(timings),
        'min_window': settings['min_window'],
        'max_window': settings['max_window'],
        'requests_timed': total_timings,
        'elapsed': elapsed_time
        })
    logging.info(msg)

    time.sleep(1) # cheaply avoid timing issues with requests library


    #
    # analyze / detect
    #

    all_dynos = dict((p.process, p) for p in app.processes['web'])
    active_dynos = []
    down_dynos = []

    for dyno_name, dyno in all_dynos.items():
        if dyno.state != 'up':
            logging.debug('dyno %s state is %r', dyno_name, dyno.state)
            down_dynos.append(dyno_name)
        elif dyno.elapsed < MIN_UPTIME + elapsed_time:
            # not presently down, but it had not been up for long enough when
            # we started capturing times, so exclude it
            msg = 'dyno %s uptime too short (%r < %d)'
            logging.debug(msg, dyno_name, dyno.elapsed, MIN_UPTIME + elapsed_time)
        else:
            logging.debug('dyno %s is active', dyno_name)
            active_dynos.append(dyno_name)

    # ensure at least 80% of dynos are presently active before continuing with
    # response time analysis.  otherwise, assume the formation is in mid-cycle
    # or mid-deploy, and skip.
    if len(active_dynos) / float(len(all_dynos)) < 0.8:
        msg = 'not enough dynos are active ({} / {}) - skipping slow dyno detection'
        return skip(msg.format(len(active_dynos), len(all_dynos)))

    # compute the mean response time across all dynos from which we captured
    # a sufficient number of timings.
    dyno_response_times = []
    timing_counts = []
    for dyno_name in active_dynos:
        timings.setdefault(dyno_name, [])
        if len(timings[dyno_name]) >= settings['min_timings']:
            timing_counts.append(len(timings[dyno_name]))
            dyno_response_times.append(average(timings[dyno_name]))

    # ensure that the number of dynos included in the sample is at least half
    # of the total size of the formation.  if not, assume we either have a
    # throughput issue, or a script configuration problem.
    if len(dyno_response_times) / float(len(all_dynos)) < 0.5:
        msg = 'less than half of dynos ({} / {}) reported enough timings for slow dyno detection'
        return alert(msg.format(len(dyno_response_times, len(all_dynos))))

    # decide the threshold of 'slow'
    mean_response_time = average(dyno_response_times)
    slow_threshold = mean_response_time + (settings['kill_threshold'] * stddev(dyno_response_times))
    effective_threshold = max([slow_threshold, settings['min_threshold']])
    msg = json.dumps({
        'dynos_timed': len(dyno_response_times),
        'mean_response_time': mean_response_time,
        'slow_threshold': slow_threshold,
        'effective_threshold': effective_threshold
        })
    logging.info(msg)

    slow_dynos = []
    for dyno_name in active_dynos:
        dts = timings[dyno_name]
        avg_response_time = average(dts)
        is_slow = avg_response_time > effective_threshold
        msg = json.dumps({
            'dyno': dyno_name,
            'requests_timed': len(dts),
            'average_response_time': avg_response_time,
            'is_slow': is_slow
            })
        log = logging.info
        if is_slow:
            log = logging.warn
            slow_dynos.append(dyno_name)
        log(msg)
    logging.info(json.dumps({'slow_dyno_count': len(slow_dynos)}))


    #
    # take action
    #

    if slow_dynos and not settings['dry_run']:
        # choose one at random and restart
        slow_dyno = random.choice(slow_dynos)
        app.processes[slow_dyno].stop()
        return alert('stopped dyno: {}'.format(slow_dyno))

    return 0


if __name__=='__main__':

    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--min-window', type=int, default=DEFAULT_MIN_TIMING_WINDOW,
            help='minimum amount of seconds to spend capturing logged timings')
    parser.add_argument('--max-window', type=int, default=DEFAULT_MAX_TIMING_WINDOW,
            help='maximum amount of seconds to spend capturing logged timings')
    parser.add_argument('--min-timings', type=int, default=DEFAULT_MIN_TIMINGS,
            help='minimum number of timings needed from a dyno to include it in response time aggregation')
    parser.add_argument('--kill-threshold', type=int, default=DEFAULT_KILL_THRESHOLD,
            help='number of stddevs above the mean that determine a slow dyno')
    parser.add_argument('--min-threshold', type=float, default=DEFAULT_MIN_THRESHOLD,
            help='minimum response time measurement a dyno must exceed before it can be considered slow')
    parser.add_argument('--dry-run', '-n', action='store_true',
            help='perform analysis but do not interfere with running dynos')
    parser.add_argument('--verbose', '-v', action='store_true',
            help='verbose output (log level DEBUG)')
    args = parser.parse_args()

    log_level = logging.INFO
    if getattr(args, 'verbose'):
        log_level = logging.DEBUG

    logging.basicConfig(level=log_level, stream=sys.stderr,
                format='%(asctime)s %(module)s %(levelname)s %(message)s')
    # ignore noisy output from requests
    if log_level > logging.DEBUG:
        logging.getLogger("requests.packages.urllib3").setLevel(logging.WARN)

    logging.debug('hi')
    h = heroku.from_key(os.getenv('HEROKU_API_KEY'))
    app = h.apps[os.getenv('NEW_RELIC_APP_NAME')]
    
    logging.info('starting slow dyno detection')
    try:
        exit_code = main(app, vars(args))
    except:
        logging.error('slow dyno detection failed', exc_info=1)
        exit_code = 1
    logging.info('slow dyno detection completed')
    sys.exit(exit_code)
