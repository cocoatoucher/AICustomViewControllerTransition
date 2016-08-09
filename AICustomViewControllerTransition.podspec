Pod::Spec.new do |s|
  s.name = 'AICustomViewControllerTransition'
  s.version = '1.0.1'
  s.license = 'MIT'
  s.summary = 'Easy and tidy way for creating custom UIViewController transitions for iOS'
  s.homepage = 'https://github.com/cocoatoucher/AICustomViewControllerTransition'
  s.authors = { 'cocoatoucher' => 'cocoatoucher@aol.com' }
  s.source = { :git => 'https://github.com/cocoatoucher/AICustomViewControllerTransition.git', :tag => s.version }
  s.ios.deployment_target = '8.1'
  s.source_files = 'Source/*.swift'
  s.requires_arc = true
end
