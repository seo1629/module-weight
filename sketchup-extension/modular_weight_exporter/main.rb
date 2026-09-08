# 확장 프로그램 진입점. Extension Manager에서 켜지면 SketchUp이 이 파일을 로드한다.
require 'json'

dir = File.dirname(__FILE__)
require File.join(dir, 'core.rb')
require File.join(dir, 'geometry.rb')
require File.join(dir, 'builder.rb')
require File.join(dir, 'auto_detect.rb')
require File.join(dir, 'exporter.rb')
require File.join(dir, 'tools.rb')
require File.join(dir, 'commands.rb')
require File.join(dir, 'menu.rb')

ModularWeightExporter::Menu.register!
