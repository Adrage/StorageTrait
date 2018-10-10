Pod::Spec.new do |s|
  s.platform     = :ios
  s.ios.deployment_target = '10.0'
  s.name         = "StorageTrait"
  s.summary      = "All storage methods to include Firebase Storage and Real-time database"
  s.requires_arc = true

  s.version      = "0.0.1"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.authors      = { "Adrian C. Johnson" => "acjohn624@gmail.com", "Vincent Cepeda" => "vcepeda858@gmail.com" }
  
  s.homepage     = "https://github.com/Adrage/StorageTrait"

  s.source       = { :git => "https://github.com/Adrage/StorageTrait.git", :tag => "#{s.version}"}
  
  s.frameworks = "FirebaseAuth", "FirebaseCore", "FirebaseDatabase", "FirebaseFirestore", "FirebaseStorage", "FirebaseUI"

  s.dependency "Firebase/Auth"
  s.dependency "Firebase/Core"
  s.dependency "Firebase/Database"
  s.dependency "Firebase/Firestore"
  s.dependency "Firebase/Storage"
  s.dependency "FirebaseUI/Storage"
  s.dependency "RxSwift"

  s.source_files = "StorageTrait/**/*.{swift}"
  s.static_framework = true
  s.swift_version = "4.0"
end
