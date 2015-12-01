require 'command_line_reporter'
class Razor::CLI::TableFormat
  include CommandLineReporter

  def run(doc, column_overrides)
    suppress_output
    table(:border => true, :encoding => :ascii) do
      headings = (column_overrides or get_headers(doc))
      row do
        headings.each do |header|
          column(header, :width => column_width!(headings, header, doc))
        end
      end
      doc.each do |page|
        row do
          headings.each do |heading|
            column(page[heading])
          end
        end
      end
    end
    # Capturing stores the string, rather than printing to STDOUT (default).
    capture_output.strip
  end

  # This method has the side effect of modifying the remaining extra_width.
  # It pulls everything together to come up with a single value for the column.
  def column_width!(headings, header, doc)
    content_width = content_width(header, doc)
    average_width = average_width(headings)
    # Is the column too wide and can we do anything about it?
    if content_width > average_width && extra_width(headings, doc) > 0
      # Determine how much room we'd need to make to accommodate the content.
      remaining = content_width - average_width
      # Add back in what we can.
      width = average_width + [@extra_width, remaining].min
      # The new width can't be negative.
      @extra_width = [@extra_width - remaining, 0].max
      width
    else
      [content_width, average_width].min
    end
  end

  # This calculates how much leeway would exist in all columns if we were to
  # use an auto-sized fixed width for the whole table.
  def extra_width(headings, doc)
    @extra_width ||= headings.map do |header|
                       [average_width(headings) - content_width(header, doc), 0].max
                     end.inject(:+)
  end

  # This calculates what an auto-sized fixed-width table's column width would be.
  def average_width(headings)
    # The 3 here = 2 for width gap + 1 for the column separator.
    # The 1 is for the last separator.
    console_width = `stty size | cut -d ' ' -f 2 2>/dev/null`
    if console_width.nil? || console_width.to_i <= 0
      console_width = 80
    end
    @average_width ||= ((console_width.to_i - (headings.count * 3) - 1) / headings.count)
  end

  def content_width(header, doc)
    # Find longest item, including the header
    (doc.map do |page|
      (page[header] or '').to_s.length
    end << header.to_s.length).max
  end

  # Traverse all headers to compile a unique list.
  def get_headers(doc)
    [].tap do |headers|
      doc.map do |page|
        page.map do |item|
          headers << item[0] unless headers.include?(item[0])
        end
      end
    end
  end
end