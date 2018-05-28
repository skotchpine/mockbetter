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
    MockBetter.conf = {
      'headers' => {},
      'prefix' => '',
      'default' => {
        'code' => '200',
        'body' => { 'message' => 'mock better' },
        'mode' => 'mock',
      },
      'tenants' => {},
    }
    MockBetter.conf['headers']['Content-Type'] = 'application/json'
  end

  def new_tenant
    {
      'history' => [],
      'routes' => [],
    }
  end

  def tenant(name)
    MockBetter.conf['tenants'][name] ||= new_tenant
  end

  def send_conf
    ['200', MockBetter.conf['headers'], [MockBetter.conf.to_json]]
  end

  def send_error(msg)
    ['500', MockBetter.conf['headers'], [{ 'message': msg}.to_json]]
  end

  def send_okay(body)
    ['200', MockBetter.conf['headers'], [body.to_json]]
  end

  def default(method, path, body)
    if MockBetter.conf['default']['mode'] == 'dump'
      send_okay({ path: '/' + path.join('/'), method: method })
    elsif MockBetter.conf['default']['mode'] == 'echo'
      send_okay body
    else # mock
      [
        MockBetter.conf['default']['code'],
        MockBetter.conf['headers'],
        [MockBetter.conf['default']['body'].to_json]
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

    ## GET CONFIG
    if method == 'GET' && parts == %w[mock conf]
      send_conf

    ## UPDATE CONFIG
    elsif method == 'PUT' && parts == %w[mock conf]
      unless body.is_a?(Hash)
        send_error 'a json object is required'
      else
        merge_conf(MockBetter.conf, body || {})
        send_conf
      end

    ## RESET EVERYTHING
    elsif method == 'PUT' && parts == %w[mock reset]
      reset
      send_conf

    ## CREATE MOCK TENANT ROUTE
    elsif method == 'PUT' && parts[0..1] == %w[mock routes]
      unless body.is_a?(Hash)
        return send_error 'a json object is required'
      end

      name = parts[2]
      unless name
        return send_error 'a tenant is required'
      end

      tenant(name)['routes'].each do |route|
        if route['method'] == body['method'] && route['path'] == body['path']
          return send_conf
        end
      end

      tenant(name)['routes'] << body
      send_conf

    ## DELETE TENANT ROUTE
    elsif method == 'DELETE' && parts[0..1] == %w[mock routes]
      unless body.is_a?(Hash)
        return send_error 'a json object is required'
      end

      name = parts[2]
      unless name
        return send_error 'a tenant is required'
      end

      tenant(name)['routes'].reject! do |route|
        route['method'] == body['method']
        route['path'] == body['path']
      end
      send_conf

    ## GET TENANT HISTORY
    elsif method == 'GET' && parts[0..1] == %w[mock history]
      name = parts[2]
      send_okay tenant(name)['history']

    ## DELETE TENANT HISTORY
    elsif method == 'DELETE' && parts[0..1] == %w[mock history]
      name = parts[2]
      tenant(name)['history'] = []
      send_conf

    ## MOCK & DEFAULT RESPONSES
    else
      name = parts.first
      unless name
        return send_error 'a tenant is required'
      end

      tenant(name)['history'] << {
        'method' => method,
        'body' => body,
        'path' => path,
      }

      tenant(name)['routes'].each do |route|
        if (method == route['method'] || route['method'] == 'ANY') && path =~ /#{route['path']}/
          return [
            route['code'],
            MockBetter.conf['headers'].merge(route['headers'] || {}),
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
