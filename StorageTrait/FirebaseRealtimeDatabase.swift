//
//  FirebaseRealtimeDatabase.swift
//  StorageTrait
//
//  Created by Adrian C. Johnson on 10/9/18.
//  Copyright © 2018 CrossVision. All rights reserved.
//

import FirebaseDatabase
import FirebaseStorage
import FirebaseUI

// MARK: - Firebase: Realtime Database
public protocol RealtimeDatabaseType {
    var ref: DatabaseReference? { get }
    static var baseUrl: String { get }
    static var referenceString: String { get }
    
    init(snapshot: DataSnapshot?)
}

public protocol RealtimeDatabaseImageType: RealtimeDatabaseType {
    static var imageReferenceString: String { get }
    static var placeHolderImage: UIImage? { get }
    static var storageUrl: String { get }
}

extension RealtimeDatabaseImageType {
    private static var imageReference: StorageReference {
        let storage = Storage.storage()
        let url = storageUrl + imageReferenceString
        return storage.reference(forURL: url)
    }
    
    var firebaseImageRef: (reference: StorageReference, placeholderImage: UIImage?) {
        guard let imageRefKey = ref?.key else { return (StorageReference(), nil) }
        
        let imageRef = Self.imageReference.child(imageRefKey + ".png")
        return (imageRef, Self.placeHolderImage)
    }
}

// MARK: Data Manager Protocol
public protocol RealtimeDatabaseRetrievable {
    associatedtype ModelObject: RealtimeDatabaseType
    typealias CompletionHandler = ((_ objects: [Self]) -> Void)?
    
    static func getData(withCompletion: CompletionHandler, failure: FailureHandler)
    
    var object: ModelObject? { get set }
    func dictionaryRepresentation() -> [String : Any]
    
    init()
}

extension RealtimeDatabaseRetrievable {
    public init(model: ModelObject) {
        self.init()
        object = model
    }
    
    public static var reference: DatabaseReference? {
        let url = ModelObject.baseUrl + ModelObject.referenceString
        return Database.database().reference(fromURL: url)
    }
    
    public static func getData(withCompletion completion: CompletionHandler = nil, failure: FailureHandler = nil) {
        reference?.observe(.value, with: { (snapshot) in
            let array = snapshot.children.map { Self(model: ModelObject(snapshot: $0 as? DataSnapshot))}
            completion?(array)
            return
        }) { (error) in
            failure?(error)
        }
    }
    
    @discardableResult public func saveObjectInDB() -> String? {
        guard let autoID = self.object?.ref?.childByAutoId() else { return nil }
        autoID.setValue(dictionaryRepresentation())
        return autoID.key
    }
}

extension RealtimeDatabaseRetrievable where Self.ModelObject: RealtimeDatabaseImageType {
    public var image: (reference: StorageReference, placeholderImage: UIImage?) {
        guard let imageRef = object?.firebaseImageRef else { return (StorageReference(), nil) }
        return imageRef
    }
}
