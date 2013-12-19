# encoding: utf-8

shared_examples "unicode data" do
  it "can handle ASCII data" do
    test_unicode_data("This post contains ASCII.")
  end

  it "can handle Latin-1 data" do
    test_unicode_data("Thís pøst çòñtáins Lätin-1 tæxt")
  end

  it "can handle CJK data" do
    test_unicode_data("ｲんﾉ丂 ｱo丂ｲ co刀ｲﾑﾉ刀丂 cﾌズ")
  end

  it "can handle non-BMP data" do
    test_unicode_data("𝕋𝕙𝕚𝕤 𝕡𝕠𝕤𝕥 𝕔𝕠𝕟𝕥𝕒𝕚𝕟𝕤 𝕔𝕙𝕒𝕣𝕒𝕔𝕥𝕖𝕣𝕤 𝕠𝕦𝕥𝕤𝕚𝕕𝕖 𝕥𝕙𝕖 𝔹𝕄ℙ")
  end

  it "can handle special chars" do
    test_unicode_data(
      "\" This , post > contains < delimiter ] and [ other } " +
      "special { characters ; that & may ' break things"
    )
  end

  it "can handle string interpolation syntax" do
    test_unicode_data("This string contains %s string interpolation #\{syntax}")
  end
end
