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
  s.summary          = 'The JioNews-ShortsSDK-CocoaPod is a software development kit (SDK) and CocoaPod designed specifically for integrating Short Video feature into iOS applications. This toolkit provides developers with a comprehensive set of tools.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'The JioNews-ShortsSDK-CocoaPod is a software development kit (SDK) and CocoaPod designed specifically for integrating Short Video feature into iOS applications. This toolkit provides developers with a comprehensive set of tools, libraries, and APIs to seamlessly incorporate short video functionality, enabling users to capture, edit, and share brief video clips within their apps. By leveraging this SDK, developers can enrich their applications with engaging video content features, enhancing the user experience with the dynamic and popular format of short videos. This integration not only streamlines the development process but also opens up new possibilities for user engagement and content creation within the iOS ecosystem..A short description of jionews-shortssdk-cocoapod. This is SDK/Cocoapod to access Jio Short Video feature. You can init using example project.'

  s.homepage         = 'https://github.com/Nem-Emerging-World-of-Journalism/JioNews-ShortsSDK-iOS-COCOAPODS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Saif' => 'saif.mukadam@ril.com' }
  s.source           = { :git => 'https://github.com/Nem-Emerging-World-of-Journalism/JioNews-ShortsSDK-iOS-COCOAPODS.git'}
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'
  s.source_files = 'SourceCode/**/*.swift'
  
  # s.resource_bundles = {
  #   'jionews-shortssdk-cocoapod' => ['jionews-shortssdk-cocoapod/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
