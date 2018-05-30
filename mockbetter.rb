#!/usr/bin/env ruby

require 'rack'
require 'rack/server'
require 'json'

class MockBetter
  class << self
    attr_accessor :conf
  end

  def initialize
    reset
  end

  def reset
    @conf = {
      'headers' => {},
      'prefix' => 'mock',
      'default' => {
        'code' => '200',
        'body' => { 'message' => 'mock better' },
        'mode' => 'mock',
      },
      'history' => [],
      'routes' => [],
    }
    @conf['headers']['Content-Type'] = 'application/json'
  end

  def send_conf
    ['200', @conf['headers'], [@conf.to_json]]
  end

  def send_error(msg)
    ['500', @conf['headers'], [{ 'message': msg}.to_json]]
  end

  def send_okay(body)
    ['200', @conf['headers'], [body.to_json]]
  end

  def default(method, path, body)
    if @conf['default']['mode'] == 'dump'
      send_okay({ path: '/' + path.join('/'), method: method })
    elsif @conf['default']['mode'] == 'echo'
      send_okay body
    else # mock
      [
        @conf['default']['code'],
        @conf['headers'],
        [@conf['default']['body'].to_json]
      ]
    end
  end

  def call(env)
    body =
      begin
        JSON.parse(env['rack.input'].string)
      rescue JSON::ParserError
      end

    method = env['REQUEST_METHOD']
    path = env['REQUEST_PATH']
    parts = path.split('/').drop(1)
    puts parts.inspect

    ## GET CONFIG
    if method == 'GET' && parts == [@conf['prefix'], 'conf']
      send_conf

    ## UPDATE CONFIG
    elsif method == 'PUT' && parts == [@conf['prefix'], 'conf']
      unless body.is_a?(Hash)
        send_error 'a json object is required'
      else
        merge_conf(@conf, body || {})
        send_conf
      end

    ## RESET EVERYTHING
    elsif method == 'PUT' && parts == [@conf['prefix'], 'reset']
      reset
      send_conf

    ## CREATE MOCK ROUTE
    elsif method == 'PUT' && parts == [@conf['prefix'], 'routes']
      unless body.is_a?(Hash)
        return send_error 'a json object is required'
      end

      @conf['routes'].each do |route|
        if route['method'] == body['method'] && route['path'] == body['path']
          return send_conf
        end
      end

      @conf['routes'] << body
      send_conf

    ## DELETE ROUTE
    elsif method == 'DELETE' && parts == [@conf['prefix'], 'routes']
      @conf['routes'] = []
      send_conf

    ## GET HISTORY
    elsif method == 'GET' && parts == [@conf['prefix'], 'history']
      send_okay @conf['history']

    ## DELETE HISTORY
    elsif method == 'DELETE' && parts == [@conf['prefix'], 'history']
      @conf['history'] = []
      send_conf

    ## MOCK & DEFAULT RESPONSES
    else
      @conf['history'] << {
        'method' => method,
        'body' => body,
        'path' => '/' + parts.drop(1).join('/'),
      }

      @conf['routes'].each do |route|
        if (method == route['method'] || route['method'] == 'ANY') && path =~ /#{route['path']}/
          return [
            route['code'],
            @conf['headers'].merge(route['headers'] || {}),
            [route['body'].to_json]
          ]
        end
      end

      default(method, parts, body)
    end

  rescue Exception => e
    send_error "#{e.to_s}\n#{e.backtrace * "\n"}"
  end

  def merge_conf(h1, h2)
    h2.each do |k, v|
      if v.is_a?(Hash) && h1[k]&.is_a?(Hash)
        merge_conf(h1[k], v)
      elsif v.is_a?(Array) && h1[k]&.is_a?(Array)
        h1[k] |= v
      else
        h1[k] = v
      end
    end
  end
end
