require 'rubygems'
require 'sinatra'
require 'couchrest'
require 'maruku'

CouchRest::Model.default_database = CouchRest.database!('weaky')

class Item < CouchRest::Model
  key_accessor :name, :body
  view_by :name

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
    '/id/' + id
  end

  def edit_url
    '/edit/' + id
  end

  def delete_url
    id && '/delete/' + id
  end
end

get '/' do
  redirect '/home'
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

get '/stylesheet.css' do
  header 'Content-Type' => 'text/css; charset=utf-8'
  sass :stylesheet
end
