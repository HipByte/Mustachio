$:.unshift("/Library/Motion/lib")
require 'motion/project'

#ENV['debug'] ||= '0' # Because the REPL cannot be loaded with CoreImage yet.

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'Mustachio'
  #app.frameworks += ['QuartzCore', 'CoreImage', 'Twitter', 'AssetsLibrary']
  app.frameworks += ['QuartzCore', 'CoreImage', 'Twitter']
end
