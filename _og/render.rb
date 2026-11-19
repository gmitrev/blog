require "date"
require "erb"
require "fileutils"
require "yaml"

class OgCard
  include ERB::Util

  ROOT = File.expand_path("..", __dir__)
  TEMPLATES = File.join(ROOT, "_og")
  WORK = File.join(ROOT, "tmp", "og")
  OUT = File.join(ROOT, "assets", "images", "og")
  BROWSERS = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
  ].freeze

  attr_reader :slug, :title, :description, :category, :date, :lang

  def self.all
    Dir[File.join(ROOT, "_posts", "*.{md,markdown}")].sort.map { |path| new(path) }.select(&:published?)
  end

  def initialize(path)
    name = File.basename(path, File.extname(path))
    @front = YAML.safe_load(File.read(path).split(/^---\s*$/)[1], permitted_classes: [Date, Time]) || {}
    @slug = name.sub(/\A\d{4}-\d{2}-\d{2}-/, "")
    @title = @front.fetch("title").to_s
    @description = @front["description"]
    @category = Array(@front["categories"]).first
    @date = Date.parse((@front["date"] || name[0, 10]).to_s)
    @lang = @title.match?(/\p{Cyrillic}/) ? "bg" : "en"
  end

  def published?
    @front["published"] != false
  end

  def render
    template = File.join(TEMPLATES, "#{slug}.html.erb")
    template = File.join(TEMPLATES, "default.html.erb") unless File.exist?(template)
    page = File.join(WORK, "#{slug}.html")
    File.write(page, ERB.new(File.read(template)).result(binding))

    target = File.join(OUT, "#{slug}.png")
    system(browser, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
           "--window-size=1200,630", "--virtual-time-budget=3000", "--screenshot=#{target}", "file://#{page}",
           out: File::NULL, err: File::NULL) || abort("failed to render #{slug}")
    target
  end

  private

  def browser
    BROWSERS.find { |path| File.executable?(path) } || abort("install Chrome or Chromium")
  end
end

FileUtils.mkdir_p([OgCard::WORK, OgCard::OUT])
FileUtils.cp(File.join(OgCard::TEMPLATES, "card.css"), OgCard::WORK)

cards = OgCard.all
cards = cards.select { |card| ARGV.include?(card.slug) } if ARGV.any?
cards.each { |card| puts card.render.delete_prefix("#{OgCard::ROOT}/") }
