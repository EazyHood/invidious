require "../../parsers_helper.cr"

# Both payloads below are trimmed from a real `youtubei/v1/next` response for
# video IZZVijQ0gkA, taken on 2026-08-03 with the WEB client version this repo
# pins in `youtube_api.cr`. Only the fields `parse_related_video` reads were
# kept; their nesting is unchanged.

# A video credited to a single channel: the run carries a browseEndpoint, so
# the channel id is where it has always been.
SINGLE_AUTHOR = <<-JSON
  {
    "videoId": "XuoqKYxDHVc",
    "title": { "simpleText": "The full-length interview with Elon Musk | The Economist" },
    "lengthInSeconds": 5107,
    "shortViewCountText": { "simpleText": "3.1M views" },
    "publishedTimeText": { "simpleText": "4 days ago" },
    "shortBylineText": {
      "runs": [
        {
          "text": "The Economist",
          "navigationEndpoint": {
            "browseEndpoint": {
              "browseId": "UC0p5jTq6Xx_DosDFxVXnWaQ",
              "canonicalBaseUrl": "/@TheEconomist"
            }
          }
        }
      ]
    }
  }
  JSON

# A video credited to two channels. Youtube renders it as one run holding both
# names, and its navigationEndpoint opens a channel picker instead of browsing
# anywhere -- so there is no browseEndpoint on the run at all. The ids live
# inside the dialog.
MULTIPLE_AUTHORS = <<-JSON
  {
    "videoId": "LKvf-XrLCjs",
    "title": { "simpleText": "'He's Weak': Tucker Carlson on How Trump Failed America" },
    "lengthInSeconds": 3077,
    "shortViewCountText": { "simpleText": "588K views" },
    "publishedTimeText": { "simpleText": "2 weeks ago" },
    "shortBylineText": {
      "runs": [
        {
          "text": "Bloomberg Podcasts and Bloomberg Television",
          "navigationEndpoint": {
            "showDialogCommand": {
              "panelLoadingStrategy": {
                "inlineContent": {
                  "dialogViewModel": {
                    "customContent": {
                      "listViewModel": {
                        "listItems": [
                          {
                            "listItemViewModel": {
                              "title": { "content": "Bloomberg Podcasts" },
                              "rendererContext": {
                                "commandContext": {
                                  "onTap": {
                                    "innertubeCommand": {
                                      "browseEndpoint": { "browseId": "UChF5O40UBqAc82I7-i5ig6A" }
                                    }
                                  }
                                }
                              }
                            }
                          },
                          {
                            "listItemViewModel": {
                              "title": { "content": "Bloomberg Television" },
                              "rendererContext": {
                                "commandContext": {
                                  "onTap": {
                                    "innertubeCommand": {
                                      "browseEndpoint": { "browseId": "UCIALMKvObZNtJ6AmdCLP7Lg" }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        ]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  }
  JSON

Spectator.describe "parse_related_video" do
  it "parses a video credited to a single channel" do
    related = Invidious::Videos::Parser.parse_related_video(JSON.parse(SINGLE_AUTHOR))

    expect(related).to_not be_nil
    expect(related.not_nil!["id"].as_s).to eq("XuoqKYxDHVc")
    expect(related.not_nil!["author"].as_s).to eq("The Economist")
    expect(related.not_nil!["ucid"].as_s).to eq("UC0p5jTq6Xx_DosDFxVXnWaQ")
  end

  it "parses the channel of a video credited to several channels" do
    related = Invidious::Videos::Parser.parse_related_video(JSON.parse(MULTIPLE_AUTHORS))

    expect(related).to_not be_nil
    expect(related.not_nil!["author"].as_s).to eq("Bloomberg Podcasts and Bloomberg Television")

    # Without this, the ucid comes back empty and the template renders the
    # author as plain text, which is what gh-5722 reports.
    expect(related.not_nil!["ucid"].as_s).to eq("UChF5O40UBqAc82I7-i5ig6A")
  end

  it "still parses the rest of the fields for a video with several channels" do
    related = Invidious::Videos::Parser.parse_related_video(JSON.parse(MULTIPLE_AUTHORS))

    expect(related.not_nil!["id"].as_s).to eq("LKvf-XrLCjs")
    expect(related.not_nil!["length_seconds"].as_s).to eq("3077")
    expect(related.not_nil!["short_view_count"].as_s).to eq("588K")
    expect(related.not_nil!["published"].as_s).to_not be_empty
  end
end
