require "sinatra"
require "pg"
require "pry"

set :bind, '0.0.0.0'  # bind to all interfaces

configure :development do
  set :db_config, { dbname: "movies" }
end

configure :test do
  set :db_config, { dbname: "movies_test" }
end

def db_connection
  begin
    connection = PG.connect(Sinatra::Application.db_config)
    yield(connection)
  ensure
    connection.close
  end
end

get '/' do
  erb :home
end

get '/actors' do
  if params["query"]
    @actors_array = actor_query(params["query"]).to_a
  else
    @actors_array = actors_list.to_a
  end
  erb :actors
end

get '/actors/:id' do
  @actor_id = params[:id]
  @full_bio = actor_bio.to_a
  @movies_count = movies_count(@actor_id).to_a
  erb :actor_bio
end

get '/movies' do
  order = order_by(params["order"])
  rows = 20 * params["page"].to_i
  sort = params["sort"]
  if params["query"]
    query = params["query"]
    @movies_array = movies_query(order, sort, rows, query).to_a
  else
    @movies_array = movies_list(order, sort, rows).to_a
  end
  erb :movies
end

# How do I refactor get '/movies' and post '/movies' so I'm not repeating my code, but the params set in the post cross over to the get.
#
# post '/movies' do
#   # binding.pry
#   order = order_by(params["order"])
#   rows = 20 * params["page"].to_i
#   sort = params["sort"]
#   @movies_array = movies_list(order, sort, rows).to_a
#   erb :movies
# end

get '/movies/:id' do
  @movie_id = params[:id]
  @full_info = movie_info.to_a

  erb :movie_info
end

def actors_list
  db_connection { |conn| conn.exec("
    SELECT * FROM actors
    ORDER BY name
  ;") }
end

def actor_bio
  db_connection { |conn| conn.exec("
    SELECT actors.name AS actor,
      actors.id AS actor_id,
      movies.title AS movie,
      movies.id AS movie_id,
      cast_members.character AS role
    FROM actors
    JOIN cast_members
    ON (actors.id = cast_members.actor_id)
    JOIN movies
    ON (cast_members.movie_id = movies.id)
    WHERE actors.id = #{@actor_id}
    ORDER BY movies.title
  ;") }
end

def movies_list(order_by, sort, rows)
  db_connection { |conn| conn.exec("
    SELECT movies.id AS id,
      title,
      year,
      rating,
      genres.name AS genre,
      studios.name AS studio
    FROM movies
    LEFT OUTER JOIN genres
    ON (movies.genre_id = genres.id)
    LEFT OUTER JOIN studios
    ON (movies.studio_id = studios.id)
    ORDER BY #{order_by} #{sort} NULLS LAST
    OFFSET #{rows} ROWS
    FETCH NEXT 20 ROWS ONLY
  ;") }
end

def movie_info
  db_connection { |conn| conn.exec("
    SELECT movies.id AS id,
      title,
      year,
      rating,
      genres.name AS genre,
      studios.name AS studio,
      cast_members.character AS role,
      actors.name AS actor,
      actors.id AS actor_id
    FROM movies
    LEFT OUTER JOIN genres
    ON (movies.genre_id = genres.id)
    LEFT OUTER JOIN studios
    ON (movies.studio_id = studios.id)
    LEFT OUTER JOIN cast_members
    ON (movies.id = cast_members.movie_id)
    JOIN actors
    ON (cast_members.actor_id = actors.id)
    WHERE movies.id = #{@movie_id}
    ORDER BY title, cast_members.character
  ;") }
end

def order_by(order)
  if order == "rating"
    "rating"
  elsif order == "year"
    "year"
  else
    "title"
  end
end

def movies_query(order_by, sort, rows, query)
  db_connection { |conn| conn.exec("
    SELECT movies.id AS id,
      title,
      year,
      rating,
      genres.name AS genre,
      studios.name AS studio
    FROM movies
    LEFT OUTER JOIN genres
    ON (movies.genre_id = genres.id)
    LEFT OUTER JOIN studios
    ON (movies.studio_id = studios.id)
    WHERE title ILIKE '%#{query}%'
    ORDER BY #{order_by} #{sort} NULLS LAST
    OFFSET #{rows} ROWS
    FETCH NEXT 20 ROWS ONLY
  ;") }
end

def actor_query(query)
  db_connection { |conn| conn.exec("
    SELECT * FROM actors
    WHERE actors.name ILIKE '%#{query}%'
    ORDER BY name
  ;") }
end

def movies_count(actor_id)
  db_connection { |conn| conn.exec("
    SELECT COUNT(*) FROM movies
    JOIN cast_members
    ON (movies.id = cast_members.movie_id)
    JOIN actors
    ON (actors.id = cast_members.actor_id)
    WHERE actors.id = '#{actor_id}'
    GROUP BY actors.id
  ;") }
end
