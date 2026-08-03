require "../spec_helper"

Spectator.describe "add_hashtag_links" do
  it "links a hashtag at the end of a title" do
    expect(add_hashtag_links("My great video #shorts"))
      .to eq("My great video <a href=\"/hashtag/shorts\">#shorts</a>")
  end

  it "links several hashtags" do
    expect(add_hashtag_links("Cooking #food #recipe"))
      .to eq("Cooking <a href=\"/hashtag/food\">#food</a> <a href=\"/hashtag/recipe\">#recipe</a>")
  end

  it "links a hashtag at the start" do
    expect(add_hashtag_links("#shorts and the rest"))
      .to eq("<a href=\"/hashtag/shorts\">#shorts</a> and the rest")
  end

  it "leaves a title without hashtags alone" do
    expect(add_hashtag_links("Nothing to see here")).to eq("Nothing to see here")
  end

  it "does not link a '#' that is part of a word" do
    # "C#" is not a hashtag on Youtube either: the '#' has to start the token.
    expect(add_hashtag_links("Learning C# today")).to eq("Learning C# today")
  end

  it "does not link the digits of a numeric character reference" do
    # The title arrives HTML-escaped, so an apostrophe is "&#39;" -- the "#39"
    # in there must not become a link.
    expect(add_hashtag_links("It&#39;s fine")).to eq("It&#39;s fine")
    expect(add_hashtag_links("It&#39;s fine #shorts"))
      .to eq("It&#39;s fine <a href=\"/hashtag/shorts\">#shorts</a>")
  end

  it "does not swallow an escaped tag that follows" do
    expect(add_hashtag_links("#tag &lt;b&gt;"))
      .to eq("<a href=\"/hashtag/tag\">#tag</a> &lt;b&gt;")
  end

  it "percent-encodes a hashtag that needs it" do
    expect(add_hashtag_links("#año2026"))
      .to eq("<a href=\"/hashtag/a%C3%B1o2026\">#año2026</a>")
  end

  it "ignores a lone '#'" do
    expect(add_hashtag_links("just a # sign")).to eq("just a # sign")
  end

  # Youtube counts offsets inside its own text in UTF-16 code units while
  # Crystal counts codepoints, which is a real source of off-by-one bugs when a
  # title holds an emoji. This function does not index into the string, so the
  # cases below are here to keep it that way.
  it "links a hashtag after an emoji outside the BMP" do
    expect(add_hashtag_links("Fiesta 🎉 #shorts"))
      .to eq("Fiesta 🎉 <a href=\"/hashtag/shorts\">#shorts</a>")
  end

  it "links a hashtag written straight after an emoji" do
    expect(add_hashtag_links("Fiesta 🎉#shorts"))
      .to eq("Fiesta 🎉<a href=\"/hashtag/shorts\">#shorts</a>")
  end

  it "links a hashtag after a flag, which is two surrogate pairs" do
    expect(add_hashtag_links("🇪🇸 #espana"))
      .to eq("🇪🇸 <a href=\"/hashtag/espana\">#espana</a>")
  end

  # This inserts markup into a string that is rendered unescaped, so the cases
  # below pin the two things that keep that safe: the title has been through
  # HTML.escape already, so a quote arrives as &quot; or &#39;, and the tag
  # stops at '&', so it can never run into one of those.
  describe "does not let a title inject markup" do
    it "stops the tag before an escaped double quote" do
      expect(add_hashtag_links(HTML.escape(%q{#a" onmouseover="alert(1)})))
        .to eq("<a href=\"/hashtag/a\">#a</a>&quot; onmouseover=&quot;alert(1)")
    end

    it "stops the tag before an escaped single quote" do
      expect(add_hashtag_links(HTML.escape(%q{#a' onfocus='alert(1)})))
        .to eq("<a href=\"/hashtag/a\">#a</a>&#39; onfocus=&#39;alert(1)")
    end

    it "stops the tag before an escaped closing tag" do
      expect(add_hashtag_links(HTML.escape(%q{#a</a><img src=x onerror=alert(1)>})))
        .to eq("<a href=\"/hashtag/a\">#a</a>&lt;/a&gt;&lt;img src=x onerror=alert(1)&gt;")
    end

    it "cannot produce a javascript: href" do
      # encode_path percent-encodes the colon, so the result stays a path.
      expect(add_hashtag_links("#javascript:alert(1)"))
        .to eq("<a href=\"/hashtag/javascript%3Aalert%281%29\">#javascript:alert(1)</a>")
    end
  end
end
