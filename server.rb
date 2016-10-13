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
  redirect '/actors'
end

get '/actors' do
  @actors_array = db_connection { |conn| conn.exec("
    SELECT * FROM actors
    ORDER BY name
  ;") }.to_a

  erb :actors
end

get '/actors/:actor_id' do
  @actor_id = params[:actor_id]
  @full_bio = entry = db_connection { |conn| conn.exec("
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
  ;") }.to_a

  erb :actor_bio
end

get '/movies' do

end

get '/movies/:movie_id' do
  
end
