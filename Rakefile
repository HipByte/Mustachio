$:.unshift("/Library/RubyMotion/lib")
require 'motion/project'

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'Mustachio'
  app.frameworks += ['QuartzCore', 'CoreImage', 'Twitter']
  app.deployment_target = '5.0'
  app.identifier = 'com.hipbyte.mustachio'
  app.icons += ['icon.png']
end
