require 'pry'
require 'json'
require 'colorize'
require 'tempfile'
require 'prawn'
require 'prawn/measurement_extensions'

RARITIES = %i(common uncommon rare)
BOOSTERS_PER_BOX = 36
BOXES = 2

class Card
  attr_reader :name, :colors, :image, :rarity

  RARITY_COLORS = { common: :green, uncommon: :light_blue, rare: :red }

  def initialize(card)
    @name = card['name']
    @colors = card['colors'] || []
    @image = card['imageName']
    @rarity = card['rarity'].downcase.to_sym
  end

  def name_with_rarity
    name[0..24].colorize(RARITY_COLORS[rarity])
  end
end

class Box < Array
  def inspect
    each_with_index.map do |booster, i|
      contents = booster.map(&:name_with_rarity).join(', ')
      "#{"%02d" % i}: #{contents}"
    end.join "\n"
  end
end

class Booster < Array
end

json = JSON.parse(File.read '3ED.json')
cards = RARITIES.inject({}) { |memo, rarity| memo[rarity] = []; memo }
json['cards'].each do |card|
  card = Card.new(card)
  next unless cards.keys.include? card.rarity
  cards[card.rarity] << card
end

boxes = []
BOXES.times do
  box = Box.new
  BOOSTERS_PER_BOX.times do
    booster = Booster.new
    json['booster'].each do |rarity|
      booster << cards[rarity.to_sym].sample
    end
    box << booster
  end
  boxes << box
end

pdf = Prawn::Document.new(top_margin: 0.25.in, right_margin: 0.5.in, bottom_margin: 0.25.in, left_margin: 0.5.in)
pdf.define_grid(columns: 3, rows: 3)

boxes.each_with_index do |box, i|
  box.each_with_index do |booster, j|
    pdf.start_new_page
    x = 0
    y = 0
    booster.each_with_index do |card, k|
      if x == 0 && y == 0
        pdf.grid(0,0).bounding_box do
          pdf.text "Box #{i}, booster #{j}, starting with card #{k}"
        end
        x += 1
      end
      pdf.grid(x,y).bounding_box do
        FileUtils.mkdir_p 'cards'
        filename = card.image.gsub(' ', '_').gsub(/[^a-z]/, '') + '.jpg'
        unless File.exist?(File.join 'cards', filename)
          `curl "http://mtgimage.com/set/3ed/#{card.image}.jpg" > cards/#{filename}`
        end
        pdf.image File.join('cards', filename), fit: [2.5.in, 3.5.in]
      end
      x += 1
      if x == 3
        y += 1
        x = 0
      end
      if y == 3
        pdf.start_new_page
        y = 0
      end
    end
  end
end

pdf.render_file 'box.pdf'