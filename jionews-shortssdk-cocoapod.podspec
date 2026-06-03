#
# Be sure to run `pod lib lint jionews-shortssdk-cocoapod.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'jionews-shortssdk-cocoapod'
  s.version          = '3.0.0'
  s.summary          = 'SDK/Cocoapod to access the JioNews Short Video feature, powered by a native AVPlayer feed.'

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

  s.ios.deployment_target = '17.0'

  s.swift_versions = ['5.9']
  s.source_files = 'SourceCode/**/*.{swift,m,h}'
  s.frameworks = 'UIKit', 'SwiftUI', 'AVFoundation', 'AVKit'

  s.resource_bundles = {
    'JioNewsShortsSDK' => ['SourceCode/**/*.xcassets']
  }

  s.dependency 'CleverTap-iOS-SDK'
end
