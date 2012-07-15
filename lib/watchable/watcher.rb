module Mongoid
  module Watcher
    extend ActiveSupport::Concern

    module ClassMethods
      def watching(class_plural_sym)
        class_plural = class_plural_sym.to_s
        class_single = class_plural.singularize
        class_name = class_single.camelize
        watched_symbol = "watched_#{class_plural}".intern

        has_and_belongs_to_many watched_symbol, class_name: class_name, inverse_of: :watchers, autosave: true

        self.class_eval <<-END
          def watch_#{class_single}(watching_object)
            if not self.watched_#{class_plural}.include? watching_object
              self.watched_#{class_plural} << watching_object
            end
          end

          def unwatch_#{class_single}(watching_object)
            self.watched_#{class_plural}.delete(watching_object)
          end
        END
      end
    end
  end
end
