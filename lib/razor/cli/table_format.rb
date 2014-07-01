require 'command_line_reporter'
class Razor::CLI::TableFormat
  include CommandLineReporter

  def run(doc, column_overrides)
    suppress_output
    table(:border => true, :encoding => :ascii) do
      headings = (column_overrides or get_headers(doc))
      row do
        headings.each do |header|
          column(header, :width => get_width(header, doc))
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

  def get_width(header, doc)
    (doc.map do |page|
      (page[header] or '').to_s.length
    end << header.to_s.length).max
  end

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