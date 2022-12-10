require 'thin'
require 'dotenv'
require './example_server'

run ExampleServer.new
