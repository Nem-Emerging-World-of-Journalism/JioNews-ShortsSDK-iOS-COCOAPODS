#
# Be sure to run `pod lib lint jionews-shortssdk-cocoapod.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'jionews-shortssdk-cocoapod'
  s.version          = '0.1.0'
  s.summary          = 'A short description of jionews-shortssdk-cocoapod. This is SDK/Cocoapod to access Jio Short Video feature.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/Nem-Emerging-World-of-Journalism/JioNews-ShortsSDK-iOS-COCOAPODS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Saif' => 'saif.mukadam@ril.com' }
  s.source           = { :git => 'https://github.com/Nem-Emerging-World-of-Journalism/JioNews-ShortsSDK-iOS-COCOAPODS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '13.0'

  s.source_files = 'jionews-shortssdk-cocoapod/**/*'
  
  # s.resource_bundles = {
  #   'jionews-shortssdk-cocoapod' => ['jionews-shortssdk-cocoapod/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
