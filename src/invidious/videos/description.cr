require "json"
require "uri"

# size < bytesize, so we need to count the number of characters that are
# two UInt16 wide.
# Taken from: https://github.com/crystal-lang/crystal/blob/8fa7f90c091aa3757821c04ee243c7ab5f67ac20/src/string/utf16.cr#L18-L20
private def utf16_length(content : String) : Int32
  u16_size = 0
  content.each_char do |char|
    u16_size += char.ord < 0x1_0000 ? 1 : 2
  end
  u16_size
end

private def copy_string(str : String::Builder, iter : Iterator, count : Int) : Int
  copied = 0
  while copied < count
    cp = iter.next
    break if cp.is_a?(Iterator::Stop)

    if cp == 0x26 # Ampersand (&)
      str << "&amp;"
    elsif cp == 0x27 # Single quote (')
      str << "&#39;"
    elsif cp == 0x22 # Double quote (")
      str << "&quot;"
    elsif cp == 0x3C # Less-than (<)
      str << "&lt;"
    elsif cp == 0x3E # Greater than (>)
      str << "&gt;"
    else
      str << cp.chr
    end

    # A codepoint from the SMP counts twice
    copied += 1 if cp > 0xFFFF
    copied += 1
  end

  return copied
end

# Custom channel emojis are represented as an attachmentRun carrying the
# emoji image, with its ":shortcode:" as placeholder text in the content.
# Standard emojis are attachmentRuns too, but their placeholder is the
# unicode emoji itself and their image is served from www.youtube.com;
# those keep their text form, like the legacy comment parser did.
private def parse_attachment_run(run : JSON::Any, text : String) : String
  source = run.dig?("element", "type", "imageType", "image", "sources").try &.as_a.try &.first?
  return text if source.nil?

  url = source["url"]?.try &.as_s
  return text if url.nil?

  host = URI.parse(url).host || ""
  return text unless host.ends_with?("ggpht.com") || host.ends_with?("googleusercontent.com")

  label = run.dig?("element", "properties", "accessibilityProperties", "label")
    .try &.as_s.try { |l| HTML.escape(l) } || text

  return String.build do |str|
    str << %(<img alt=") << label << "\" "
    str << %(src="/ggpht) << URI.parse(url).request_target << "\" "
    str << %(title=") << label << "\" "
    if width = source["width"]?
      str << %(width=") << width << "\" "
    end
    if height = source["height"]?
      str << %(height=") << height << "\" "
    end
    str << %(class="channel-emoji" />)
  end
end

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  commands = desc["commandRuns"]?.try &.as_a
  attachments = desc["attachmentRuns"]?.try &.as_a
  if commands.nil? && attachments.nil?
    # Slightly faster than HTML.escape, as we're only doing one pass on
    # the string instead of five for the standard library
    return String.build do |str|
      content_size = content.ascii_only? ? content.size : utf16_length(content)
      copy_string(str, content.each_codepoint, content_size)
    end
  end

  # Command runs (links, timestamps) and attachment runs (emojis) are
  # disjoint spans over the same content; process them in text order.
  runs = [] of Tuple(Int32, Int32, JSON::Any, Bool)
  commands.try &.each do |command|
    runs << {command["startIndex"].as_i, command["length"].as_i, command, false}
  end
  attachments.try &.each do |attachment|
    runs << {attachment["startIndex"].as_i, attachment["length"].as_i, attachment, true}
  end
  runs.sort_by! { |run| run[0] }

  # Not everything is stored in UTF-8 on youtube's side. The SMP codepoints
  # (0x10000 and above) are encoded as UTF-16 surrogate pairs, which are
  # automatically decoded by the JSON parser. It means that we need to count
  # copied byte in a special manner, preventing the use of regular string copy.
  iter = content.each_codepoint

  index = 0

  return String.build do |str|
    runs.each do |run_start, run_length, run, is_attachment|
      # An overlapping run would consume the iterator twice; keep the first.
      next if run_start < index

      # Copy the text chunk between this run and the previous if needed.
      length = run_start - index
      index += copy_string(str, iter, length)

      # We need to copy the run's text using the iterator
      # and the special function defined above.
      run_content = String.build(run_length) do |str2|
        copy_string(str2, iter, run_length)
      end

      if is_attachment
        str << parse_attachment_run(run, run_content)
      else
        link = run_content
        if on_tap = run.dig?("onTap", "innertubeCommand")
          link = parse_link_endpoint(on_tap, run_content, video_id)
        end
        str << link
      end

      index += run_length
    end

    # Copy the end of the string (past the last run).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
