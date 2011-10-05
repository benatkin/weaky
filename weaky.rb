require 'rubygems'
require 'sinatra/base'
require 'couchrest'
require 'couchrest_extended_document'
require 'maruku'
require 'haml'
require 'sass'

$couch_url = nil
if ENV['COUCH_URL']
  $couch_url = ENV['COUCH_URL']
elsif 
  $couch_url = 'http://' + ARGV[0].to_s.gsub(/^http:\/\//,"")
else
  puts 'Usage:'
  puts '  ruby weaky.rb http://localhost:5984/weaky'
  puts '  ruby weaky.rb localhost:5984/weaky'
  puts
  puts  ' Or set the environment variable COUCH_URL to the database URL'
end
$weaky = CouchRest.database!($couch_url)

class Item < CouchRest::ExtendedDocument
  use_database $weaky
  view_by :name

  property :name
  property :body

  WIKI_LINK_REGEX = /\[\[[A-Za-z0-9_\- ]+\]\]/
  ESCAPE_FOR_MARUKU = /[\[\]]/

  def escape(markdown)
    markdown.gsub(ESCAPE_FOR_MARUKU) { |s| '\\' + s }
  end

  def linkify(html)
    html.gsub(WIKI_LINK_REGEX) do |name_with_brackets|
      name = name_with_brackets[2..-3]
      items = Item.by_name(:key => name)
      cls = items.count == 0 && 'missing' || ''
      "<a href=\"/#{ name }\" class=\"#{ cls }\">#{ name }</a>"
    end
  end

  def body_html
    linkify(Maruku.new(escape(body)).to_html)
  end

  def new_url
    '/new/' + name
  end

  def url
    '/' + name
  end

  def id_url
    "/id/#{id}"
  end

  def edit_url
    '/edit/' + id
  end

  def delete_url
    id && '/delete/' + id
  end
end

class Weaky < Sinatra::Base
  get '/' do
    redirect '/home'
  end

  get '/:name.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :"/#{params[:name]}"
  end

  get '/items/all' do
    @items = Item.all
    haml :all
  end

  get '/new/:name' do
    @item = Item.new(:name => params[:name])
    @action = '/save'
    haml :edit
  end

  post '/save' do
    item = Item.new(:name => params[:name], :body => params[:body])
    item.save
    redirect item.url
  end

  get '/:name' do
    items = Item.by_name(:key => params[:name])
    if items.count == 1 then
      @item = items.first
      haml :show
    elsif items.count == 0 then
      @item = Item.new(:name => params[:name])
      redirect @item.new_url
    else
      @items = items
      @title = "disambiguation"
      haml :disambiguation
    end
  end

  get '/id/:id' do
    @item = Item.get(params[:id])
    haml :show
  end

  get '/edit/:id' do
    @item = Item.get(params[:id])
    @action = @item.id_url
    haml :edit
  end

  post '/id/:id' do
    item = Item.get(params[:id])
    item.name = params[:name]
    item.body = params[:body]
    item.save
    redirect item.url
  end

  post '/delete/:id' do
    item = Item.get(params[:id])
    url = item.url
    item.destroy
    redirect url
  end
end

if __FILE__ == $0
  Weaky.run!
end

