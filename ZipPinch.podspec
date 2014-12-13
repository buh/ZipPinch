Pod::Spec.new do |s|
  s.name             = "ZipPinch"
  s.version          = "0.1.1"
  s.summary          = "Work with zip file remotely."
  s.description      = <<-DESC
                        Work with zip file remotely. It read zip file contents without downloading itself and unzip files that you needed.

                        NOTE: ZipPinch works with AFNetworking 1.3+.
                       DESC
  s.homepage         = "https://github.com/buh/ZipPinch"
  s.license          = 'MIT'
  s.author           = { "Alexey Bukhtin" => "bukhtin@gmail.com" }
  s.source           = { :git => "https://github.com/buh/ZipPinch.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/alexey_bukhtin'

  s.platform     = :ios, '7.1'
  s.requires_arc = true

  s.source_files = 'ZipPinch/ZipPinch/*'

  s.dependency 'AFNetworking', '~> 1.3'
end
