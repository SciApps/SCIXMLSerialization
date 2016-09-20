Pod::Spec.new do |spec|
  spec.name             = 'SCIXMLSerialization'
  spec.version          = '0.1.0'
  spec.license          = { :type => 'MIT' }
  spec.homepage         = 'https://github.com/SciApps/SCIXMLSerialization'
  spec.authors          = { 'Arpad Goretity' => 'h2co3@h2co3.org', 'Oliver Kocsis' => 'okocsis@sciapps.io' }
  spec.summary          = 'Parsing and serializing XML using Cocoa collections, the right way'
  spec.source           = { :git => 'https://github.com/SciApps/SCIXMLSerialization.git', :tag => '0.1.0' }
  spec.source_files     = 'src/{NSError+SCIXMLSerialization,NSObject+SCIXMLSerialization,SCIXMLCanonicalizingTransform,SCIXMLCompactingTransform,SCIXMLSerialization,SCIXMLUtils}.{h,m}'
  spec.requires_arc     = true
  spec.libraries        = 'xml2'
  spec.xcconfig         = { 'HEADER_SEARCH_PATHS' => '${SDKROOT}/usr/include/libxml2' }
end
