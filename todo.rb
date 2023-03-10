require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"


configure do 
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do 
  def list_complete?(list)
    todos_count(list) > 0 && finished_todos_count(list) == todos_count(list)
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def finished_todos_count(list)
    list[:todos].select { |list| list[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each { |list| yield(list, lists.index(list))}
    complete_lists.each { |list| yield(list, lists.index(list))}
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, index|
      todo[:completed] ? complete_todos[todo] = index : incomplete_todos[todo] = index
    end 

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end 

before do 
  session[:lists] ||= []
end 

get "/" do
  redirect "lists"
end

# View all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do 
  erb :new_list, layout: :layout
end

# Return an error message if name is invalid. Return nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Create a new list
post "/lists" do 
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "A new list has been created"
    redirect "/lists"
  end
end

def load_list(index)
  list = session[:lists][index] if index <= session[:lists].size
  return list if list

  session[:error] = "The specific list was not found."
  redirect "/lists"
end

# View a single list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  erb :list, layout: :layout

end

# Edit a list name
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end 

# Update an existing todo list name
post "/lists/:id" do 
  id = params[:id].to_i
  @list = load_list(id)
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list name has been updated!"
    redirect "/lists/#{id}"
  end
end 

# Delete a list
post "/lists/:id/delete" do 
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "List deleted."
  redirect "/lists"
end 

# Validate todo data 
def error_for_todo_input(text)
  if !(1..150).cover?(text.size)
    "Todo must be between 1 and 150 characters."
  end
end

# Add a todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo_input(text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: params[:todo] , completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end


# Delete a todo
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo was successfully deleted."
  redirect "/lists/#{@list_id}"
end

# Complete a todo
post "/lists/:list_id/todos/:todo_id/finished" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  
  is_completed = params[:completed] == "true"

  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo was successfully updated."
  redirect "/lists/#{@list_id}"
end


# Complete all todos
post "/lists/:id/complete-all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = :true
  end 
  session[:success] = "All todos successfully completed."
  redirect "/lists/#{@list_id}"
end