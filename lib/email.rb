require 'mail'
require 'nokogumbo'
require 'mini_magick'
require 'fileutils'
require 'byebug'

class Email
  def initialize(path)
    @path = path
  end

  def generate_post
    if subject.match?(/^AW:/i) || subject.match?(/^RE:/i)
      puts "Skipping #{date} #{subject}"
      return
    end

    puts "Generating #{date} #{subject}"
    extension = html? ? 'html' : 'md'
    file_name = "./_posts/#{date}-#{subject}.#{extension}"
    File.open(file_name, 'w') do |f|
      f.puts('---')
      f.puts('layout: post')
      f.puts("title:  #{subject.inspect}")
      f.puts("date: #{date}")
      f.puts("categories: #{date.year.to_s.inspect}")
      f.puts('---')
      f.write(body)
    end

    assets.each do |asset|
      next if File.exist?(asset[:path])
      FileUtils.mkdir_p(asset[:directory])
      File.open(asset[:path], 'wb') do |f|
        f.write(asset[:content])
      end

      if asset[:content_type].match?(/^image\//)
        image = MiniMagick::Image.open(asset[:path])
        oriented = image.auto_orient
        oriented.write(asset[:path])
      end
    end
  end

  def mail
    @mail ||= Mail.read(@path)
  end

  def subject
    mail.subject
  end

  def date
    sent_at = mail.date.to_date

    if !subject.include?("#{sent_at.day}.")
      day_from_subject = subject.match(/(\d+)\.12/)&.to_a&.last&.to_i
      return Date.parse("#{sent_at.year}-#{sent_at.month}-#{day_from_subject}") if day_from_subject
    end

    sent_at
  end

  def body
    dirty_body = html? ? html_body : markdown_body
    clean_body(dirty_body)
  end

  def html_doc
    @html_doc ||= Nokogiri::HTML5.fragment(body_part.decoded)
  end

  def html_body
    assets
    html_doc.to_s
  end

  def markdown_body
    text = body_part.decoded.gsub("\r\n", "\n").gsub("\n", "\n\n")
    text << "\n\n"
    text = text.sub(/\s+$/, "\n\n")
    assets.each do |asset|
      url = URI.encode("/#{asset[:path]}")
      text << "![#{asset[:filename]}](#{url})\n\n"
    end

    return text
  end

  def body_part
    body_part ||= mail.multipart? ? (mail.html_part || mail.text_part) : mail
  end

  def content_type
    body_part.content_type
  end

  def html?
    content_type.match?(/text\/html/)
  end

  def assets
    return @assets if defined?(@assets)

    if html?
      @assets = []
      html_doc.css('img').each do |img|
        cid = img['src']
        if cid.match?(/^cid:/)
          part = cid_part(cid)
          asset = asset_from_part(part)
          img['src'] = URI.encode("/#{asset[:path]}")
          @assets << asset
        end
      end

      html_doc.css('*[background]').each do |node|
        cid = node['background']
        if cid.match?(/^cid:/)
          part = cid_part(cid)
          asset = asset_from_part(part)
          node['background'] = URI.encode("/#{asset[:path]}")
          @assets << asset
        end
      end
    else
      @assets = mail.attachments.map { |p| asset_from_part(p) }
    end

    @assets
  end

  def cid_part(cid, parent = mail)
    parent.parts.each do |part|
      if part.multipart?
        p = cid_part(cid, part)
        return p if p
      else
        return part if part.url == cid
      end
    end
    nil
  end


  def asset_from_part(part)
    directory = "assets/#{date}"
    {
      directory: directory,
      filename: part.filename,
      path: "#{directory}/#{part.filename}",
      content: part.decoded,
      content_type: part.content_type
    }
  end

  def clean_body(body)
    config = YAML.load(File.read('data_cleanup.yml'))

    config['redact']['words'].each do |word|
      body = body.gsub(word, "😎")
    end

    config['redact']['email_domains'].each do |domain|
      body = body.gsub(/[\w\.\+-]+@#{domain}/, "😎")
    end

    body
  end
end
