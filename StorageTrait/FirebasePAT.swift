//
//  FirebasePAT.swift
//  StockAssist
//
//  Created by Adrian C. Johnson on 11/13/17.
//  Copyright © 2017 ACJ Holdings, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseDatabase
import FirebaseFirestore
import FirebaseStorage
import RxSwift

public typealias FailureCompletion = ((_ error: Error) -> Void)?

public enum FireStoreObjectType {
    case collection
    case document
}

public enum WhereClause {
    case equal, lessThan, lessThanOrEqual, greaterThan, greaterThanOrEqual
}

enum DataRetrievableError: Error {
    case invalidCollectionReference
}

// MARK: - Firebase: Realtime Database
public protocol RealtimeDatabaseTrait {
    static var baseUrl: String { get }
    static var ref: DatabaseReference? { get }
    static var referenceString: String { get }

    init(snapshot: DataSnapshot?)
}

extension RealtimeDatabaseTrait {
    static var ref: DatabaseReference? {
        let url = baseUrl + referenceString
        return Database.database().reference(fromURL: url)
    }
}

public protocol RealtimeDatabaseImageTrait: RealtimeDatabaseTrait {
    static var firebaseImageRef: (reference: StorageReference, placeholderImage: UIImage?) { get }
    static var imageReferenceString: String { get }
    static var imageReference: StorageReference { get }
    static var placeHolderImage: UIImage? { get }
    static var storageUrl: String { get }
}

extension RealtimeDatabaseImageTrait {
    static var firebaseImageRef: (reference: StorageReference, placeholderImage: UIImage?) {
        if let imageRefKey = Self.ref?.key {
            let imageRef = Self.imageReference.child(imageRefKey + ".png")
            return (imageRef, Self.placeHolderImage)
        }
        return (StorageReference(), nil)
    }

    static var imageReference: StorageReference {
        let storage = Storage.storage()
        let url = storageUrl + imageReferenceString
        return storage.reference(forURL: url)
    }
}

// Data Manager Protocol
public protocol RealtimeDatabaseRetrievable {
    associatedtype modelObject: RealtimeDatabaseTrait

    var object: modelObject? { get set }
    static var objects: [Self] { get set }

    static func getData(withCompletion: ((_ objects: [Self]) -> Void)?, failure: FailureCompletion)

    init()
}

extension RealtimeDatabaseRetrievable {
    init(obj: modelObject) {
        self.init()
        object = obj
    }

    static func getData(withCompletion: ((_ objects: [Self]) -> Void)?, failure: FailureCompletion) {

    }
}

// MARK: - Firebase: Cloud Firestore
public protocol CloudFirestoreTrait {
    static var colRef: CollectionReference? { get }
    static var docRef: DocumentReference? { get }
    static var collectionDocumentPathString: String? { get }
    static var collectionString: String? { get }
    static var documentString: String? { get }
    static var fsObjectType: FireStoreObjectType { get }
    
    var refID: String? { get set }
    
    init(snapshot: DocumentSnapshot?)
    init(obj: Self, refID: String)
}

extension CloudFirestoreTrait {
    public init(obj: Self, refID: String) {
        self = obj
        self.refID = refID
    }
    
    public static var colRef: CollectionReference? {
        var ref: CollectionReference? = nil
        if let _collectionString = collectionString, documentString == nil {
            ref = Firestore.firestore().collection(_collectionString)
        }
        return ref
    }
    
    //TODO: This code will be used for a document, so will need to check if collection or reference for this code
    public static var docRef: DocumentReference? {
        var ref: DocumentReference? = nil
        if let _collectionDocumentPathString = collectionDocumentPathString {
            ref = Firestore.firestore().document(_collectionDocumentPathString)
        } /*else if let _collectionString = collectionString, self.documentString == nil {
         ref = Firestore.firestore().collection(_collectionString).document()
         }*/
        return ref
    }
}

public protocol CloudFirestoreImageTrait: CloudFirestoreTrait {
    var firebaseImageRef: (reference: StorageReference?, placeholderImage: UIImage?) { get }
    static var imageReferenceString: String { get }
    static var imageReference: StorageReference { get }
    static var placeHolderImage: UIImage? { get }
    static var storageUrl: String { get }
}

extension CloudFirestoreImageTrait {
    public var firebaseImageRef: (reference: StorageReference?, placeholderImage: UIImage?) {
        guard let imageRefKey = self.refID else { return (nil, nil) }

        let imageRef = Self.imageReference.child(imageRefKey + ".png")
        return (imageRef, Self.placeHolderImage)
    }

    public static var imageReference: StorageReference {
        let storage = Storage.storage()
        let url = storageUrl + imageReferenceString
        return storage.reference(forURL: url)
    }
}

// Data Manager Protocol
public protocol DataRetrievable {
    associatedtype ModelObject: CloudFirestoreTrait
    typealias Completion = ((_ objects: [Self]) -> Void)?

    var object: ModelObject? { get set }

    static var objects: [Self] { get set }

    static func getData(withCompletion: ((_ objects: [Self]) -> Void)?, failure: FailureCompletion)
    static func getData(where field: String?, is whereClause: WhereClause?, to value: Any) -> Observable<[Self]>

    func refID() -> String?
    func dictionaryRepresentation() -> [String : Any]

    init()
}

extension DataRetrievable {
    public init(obj: ModelObject) {
        self.init()
        object = obj
    }

    public static func getData(withCompletion completion: (([Self]) -> Void)?, failure: FailureCompletion = nil) {
        switch Self.ModelObject.fsObjectType {
        case .collection:
            ModelObject.colRef?.getDocuments(completion: { (snapshot, error) in
                if let _error = error {
                    failure?(_error)
                    return
                } else if let _snapshot = snapshot, !_snapshot.isEmpty {
                    let array = _snapshot.documents.map { Self(obj: ModelObject(snapshot: $0))}
                    Self.objects = array
                    completion?(array)
                    return
                }

                let error = NSError(domain: "Data Error", code: 6, userInfo: nil)
                Self.objects = []
                failure?(error)
                return
            })
        case .document:
            ModelObject.docRef?.getDocument { (snapshot, error) in
                if let _error = error {
                    failure?(_error)
                    return
                } else if let _snapshot = snapshot, _snapshot.exists {
                    let object = Self(obj: ModelObject(snapshot: _snapshot))
                    var array = [Self]()
                    array.append(object)
                    completion?(array)
                    return
                }

                let error = NSError(domain: "Data Error", code: 6, userInfo: nil)
                failure?(error)
                return
            }
        }
    }
    
    public static func getData(where field: String?, is whereClause: WhereClause?, to value: Any) -> Observable<[Self]> {
        return Observable.create({ observer -> Disposable in
            func handleDocuments(_ snapshot: QuerySnapshot?, with error: Error?) {
                guard let snapshot = snapshot else {
//                    Logger.warn.log(message: "Failed to retrieve documents: \(error.debugDescription)")
                    if let error = error {
                        observer.onError(error)
                    }
                    return
                }
                
                let array = snapshot.documents.compactMap { Self(obj: ModelObject(snapshot: $0)) }
                Self.objects = array
                observer.onNext(array)
            }
            
            guard let collectionRef = ModelObject.colRef else {
//                Logger.warn.log(message: "Failed to retrieve collection, invalid collection ref: \(String(describing: ModelObject.collectionString))")
                observer.onError(DataRetrievableError.invalidCollectionReference)
                
                return  Disposables.create()
            }
            
            if let field = field,
                let whereClause = whereClause {
                switch whereClause {
                case .equal:
                    collectionRef.whereField(field, isEqualTo: value).getDocuments {
                        handleDocuments($0, with: $1)
                    }
                case .lessThan:
                    collectionRef.whereField(field, isLessThan: value).getDocuments {
                        handleDocuments($0, with: $1)
                    }
                case .lessThanOrEqual:
                    collectionRef.whereField(field, isLessThanOrEqualTo: value).getDocuments {
                        handleDocuments($0, with: $1)
                    }
                case .greaterThan:
                    collectionRef.whereField(field, isGreaterThan: value).getDocuments {
                        handleDocuments($0, with: $1)
                    }
                case .greaterThanOrEqual:
                    collectionRef.whereField(field, isGreaterThanOrEqualTo: value).getDocuments {
                        handleDocuments($0, with: $1)
                    }
                }
            } else {
                collectionRef.getDocuments {
                    handleDocuments($0, with: $1)
                }
            }
            
            return Disposables.create()
        })
    }

    public func refID() -> String? {
        return object?.refID
    }

    public func colRef() -> CollectionReference? {
        return ModelObject.colRef
    }

    public func docRef() -> DocumentReference? {
        guard let colRef = ModelObject.colRef, let refID = object?.refID else { return nil }

        return colRef.document(refID)
    }

    public func addToOnlineService(completionBlock completion: ((_ ref: DocumentReference) -> Void)? = nil, failureBlock failure: FailureCompletion = nil) {
        async(globalBackgroundQueue) {
            var ref: DocumentReference? = nil
            ref = ModelObject.colRef?.addDocument(data:
                self.dictionaryRepresentation()
            ) { error in
                if let error = error {
                    print(error.localizedDescription)
                    async {
                        failure?(error)
                    }
                } else {
                    let modelObject = ModelObject(obj: self.object!, refID: ref!.documentID)
                    let newObject = Self(obj: modelObject)
                    Self.objects.append(newObject)

                    async {
                        completion?(ref!)
                    }
                }
            }
        }
    }

    public func deleteFromOnlineService(completionBlock completion: (() -> Void)? = nil, failureBlock failure: FailureCompletion = nil) {
        async(globalBackgroundQueue) {
            self.docRef()?.delete(completion: { error in
                if let error = error {
                    async {
                        failure?(error)
                    }
                } else {
                    for (index, item) in Self.objects.enumerated() {
                        if item.docRef()?.documentID == self.docRef()?.documentID {
                            Self.objects.remove(at: index)
                        }
                    }

                    async {
                        completion?()
                    }
                }
            })
        }
    }
}

extension DataRetrievable where Self.ModelObject: CloudFirestoreImageTrait {
    public var image: (reference: StorageReference?, placeholderImage: UIImage?) {
        guard let imageRef = object?.firebaseImageRef else { return (StorageReference(), nil) }
        return imageRef
    }
}
