require "../../parsers_helper.cr"

# Both payloads are trimmed from a real youtubei/v1/next response for video
# IZZVijQ0gkA, taken on 2026-08-03 with the WEB client version this repo pins
# in youtube_api.cr. Only the fields parse_related_lockup reads were kept;
# their nesting is unchanged.
#
# Since 2026-05-21 the secondary results of a watch page carry these rather
# than compactVideoRenderer: that response held 20 lockupViewModel and no
# compactVideoRenderer at all.

VERIFIED_CHANNEL = <<-JSON
    {
      "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
      "contentId": "XuoqKYxDHVc",
      "contentImage": {
        "thumbnailViewModel": {
          "overlays": [
            {
              "thumbnailBottomOverlayViewModel": {
                "badges": [
                  {
                    "thumbnailBadgeViewModel": {
                      "text": "1:25:07"
                    }
                  }
                ]
              }
            }
          ]
        }
      },
      "metadata": {
        "lockupMetadataViewModel": {
          "title": {
            "content": "The full-length interview with Elon Musk | The Economist"
          },
          "image": {
            "decoratedAvatarViewModel": {
              "rendererContext": {
                "commandContext": {
                  "onTap": {
                    "innertubeCommand": {
                      "browseEndpoint": {
                        "browseId": "UC0p5jTq6Xx_DosDFxVXnWaQ"
                      }
                    }
                  }
                }
              }
            }
          },
          "metadata": {
            "contentMetadataViewModel": {
              "metadataRows": [
                {
                  "metadataParts": [
                    {
                      "text": {
                        "content": "The Economist",
                        "attachmentRuns": [
                          {
                            "element": {
                              "type": {
                                "imageType": {
                                  "image": {
                                    "sources": [
                                      {
                                        "clientResource": {
                                          "imageName": "CHECK_CIRCLE_FILLED"
                                        }
                                      }
                                    ]
                                  }
                                }
                              }
                            }
                          }
                        ]
                      }
                    }
                  ]
                },
                {
                  "metadataParts": [
                    {
                      "text": {
                        "content": "3.1M views"
                      }
                    },
                    {
                      "text": {
                        "content": "4 days ago"
                      }
                    }
                  ]
                }
              ]
            }
          }
        }
      }
    }
  JSON

UNVERIFIED_CHANNEL = <<-JSON
    {
      "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
      "contentId": "6aNh6sBpqvQ",
      "contentImage": {
        "thumbnailViewModel": {
          "overlays": [
            {
              "thumbnailBottomOverlayViewModel": {
                "badges": [
                  {
                    "thumbnailBadgeViewModel": {
                      "text": "1:00:28"
                    }
                  }
                ]
              }
            }
          ]
        }
      },
      "metadata": {
        "lockupMetadataViewModel": {
          "title": {
            "content": "Game Theory #23:  The WWIII Chessboard"
          },
          "image": {
            "decoratedAvatarViewModel": {
              "rendererContext": {
                "commandContext": {
                  "onTap": {
                    "innertubeCommand": {
                      "browseEndpoint": {
                        "browseId": "UC11aHtNnc5bEPLI4jf6mnYg"
                      }
                    }
                  }
                }
              }
            }
          },
          "metadata": {
            "contentMetadataViewModel": {
              "metadataRows": [
                {
                  "metadataParts": [
                    {
                      "text": {
                        "content": "Predictive History"
                      }
                    }
                  ]
                },
                {
                  "metadataParts": [
                    {
                      "text": {
                        "content": "917K views"
                      }
                    },
                    {
                      "text": {
                        "content": "2 months ago"
                      }
                    }
                  ]
                }
              ]
            }
          }
        }
      }
    }
  JSON

Spectator.describe "parse_related_lockup" do
  it "parses a video from a verified channel" do
    related = Invidious::Videos::Parser.parse_related_lockup(JSON.parse(VERIFIED_CHANNEL))

    expect(related).to_not be_nil
    related = related.not_nil!

    expect(related["id"].as_s).to eq("XuoqKYxDHVc")
    expect(related["title"].as_s).to eq("The full-length interview with Elon Musk | The Economist")
    expect(related["author"].as_s).to eq("The Economist")
    expect(related["ucid"].as_s).to eq("UC0p5jTq6Xx_DosDFxVXnWaQ")
    expect(related["length_seconds"].as_s).to eq("5107")
    expect(related["short_view_count"].as_s).to eq("3.1M")
    expect(related["published"].as_s).to_not be_empty
  end

  it "reads the verified check off the channel name" do
    related = Invidious::Videos::Parser.parse_related_lockup(JSON.parse(VERIFIED_CHANNEL))
    expect(related.not_nil!["author_verified"].as_s).to eq("true")
  end

  it "does not mark an unverified channel as verified" do
    related = Invidious::Videos::Parser.parse_related_lockup(JSON.parse(UNVERIFIED_CHANNEL))

    expect(related).to_not be_nil
    related = related.not_nil!

    expect(related["author"].as_s).to eq("Predictive History")
    expect(related["ucid"].as_s).to eq("UC11aHtNnc5bEPLI4jf6mnYg")
    expect(related["short_view_count"].as_s).to eq("917K")
    expect(related["author_verified"].as_s).to eq("false")
  end

  it "ignores a lockup that is not a video" do
    playlist = JSON.parse(%({"contentType": "LOCKUP_CONTENT_TYPE_PLAYLIST", "contentId": "PL123"}))
    expect(Invidious::Videos::Parser.parse_related_lockup(playlist)).to be_nil
  end

  it "returns nil rather than raising on a lockup with no metadata" do
    bare = JSON.parse(%({"contentType": "LOCKUP_CONTENT_TYPE_VIDEO", "contentId": "abc"}))
    expect(Invidious::Videos::Parser.parse_related_lockup(bare)).to be_nil
  end
end

Spectator.describe "parse_video_info related videos" do
  # The mock still carries the old container, so it doubles as the check that
  # nothing regressed for clients that keep answering with it.
  it "still reads compactVideoRenderer from the secondary results" do
    raw_data = load_mock("video/regular_mrbeast.player")
      .merge!(load_mock("video/regular_mrbeast.next"))

    info = Invidious::Videos::Parser.parse_video_info("2isYuQZMbdU", raw_data)

    expect(info["relatedVideos"].as_a.size).to eq(20)
  end

  # Swapping the container is what tells us the new branch is actually reached,
  # rather than only that the leaf parser works when called by hand.
  #
  # Without that branch this does not come back empty -- it comes back with the
  # 12 entries of the endScreenVideoRenderer fallback, which is the shape of the
  # bug: the secondary results are skipped in silence and something plausible
  # but smaller is served instead.
  it "reads lockupViewModel from the secondary results" do
    _next = load_mock("video/regular_mrbeast.next")

    secondary = _next["contents"].as_h["twoColumnWatchNextResults"].as_h
      .["secondaryResults"].as_h["secondaryResults"].as_h

    secondary["results"] = JSON.parse(<<-JSON)
      [
        {"lockupViewModel": #{VERIFIED_CHANNEL}},
        {"lockupViewModel": #{UNVERIFIED_CHANNEL}}
      ]
      JSON

    raw_data = load_mock("video/regular_mrbeast.player").merge!(_next)
    info = Invidious::Videos::Parser.parse_video_info("2isYuQZMbdU", raw_data)

    related = info["relatedVideos"].as_a
    expect(related.size).to eq(2)

    expect(related[0]["id"].as_s).to eq("XuoqKYxDHVc")
    expect(related[0]["ucid"].as_s).to eq("UC0p5jTq6Xx_DosDFxVXnWaQ")
    expect(related[0]["author_verified"].as_s).to eq("true")

    expect(related[1]["id"].as_s).to eq("6aNh6sBpqvQ")
    expect(related[1]["author"].as_s).to eq("Predictive History")
  end
end
