//
// LaMaFP16.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class LaMaFP16Input : MLFeatureProvider {

    /// image as color (kCVPixelFormatType_32BGRA) image buffer, 1024 pixels wide by 1024 pixels high
    var image: CVPixelBuffer

    /// mask as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 1024 pixels wide by 1024 pixels high
    var mask: CVPixelBuffer

    var featureNames: Set<String> {
        get {
            return ["image", "mask"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "image") {
            return MLFeatureValue(pixelBuffer: image)
        }
        if (featureName == "mask") {
            return MLFeatureValue(pixelBuffer: mask)
        }
        return nil
    }
    
    init(image: CVPixelBuffer, mask: CVPixelBuffer) {
        self.image = image
        self.mask = mask
    }

}


/// Model Prediction Output Type
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class LaMaFP16Output : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// output as color (kCVPixelFormatType_32BGRA) image buffer, 1024 pixels wide by 1024 pixels high
    var output: CVPixelBuffer {
        return self.provider.featureValue(for: "output")!.imageBufferValue!
    }

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(output: CVPixelBuffer) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["output" : MLFeatureValue(pixelBuffer: output)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class LaMaFP16 {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class func urlOfModelInThisBundle(modelName: String) -> URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: modelName, withExtension:"mlmodelc")!
    }

    /**
        Construct LaMaFP16 instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of LaMaFP16.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `LaMaFP16.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(modelName: String, configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle(modelName: modelName), configuration: configuration)
    }

    /**
        Construct LaMaFP16 instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }


    /**
        Construct LaMaFP16 instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<LaMaFP16, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(LaMaFP16(model: model)))
            }
        }
    }

    /**
        Construct LaMaFP16 instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> LaMaFP16 {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return LaMaFP16(model: model)
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as LaMaFP16Input

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as LaMaFP16Output
    */
    func prediction(input: LaMaFP16Input) throws -> LaMaFP16Output {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as LaMaFP16Input
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as LaMaFP16Output
    */
    func prediction(input: LaMaFP16Input, options: MLPredictionOptions) throws -> LaMaFP16Output {
        let outFeatures = try model.prediction(from: input, options:options)
        return LaMaFP16Output(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        - parameters:
           - input: the input to the prediction as LaMaFP16Input
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as LaMaFP16Output
    */
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
    func prediction(input: LaMaFP16Input, options: MLPredictionOptions = MLPredictionOptions()) async throws -> LaMaFP16Output {
        let outFeatures = try await model.prediction(from: input, options:options)
        return LaMaFP16Output(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - image as color (kCVPixelFormatType_32BGRA) image buffer, 1024 pixels wide by 1024 pixels high
            - mask as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 1024 pixels wide by 1024 pixels high

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as LaMaFP16Output
    */
    func prediction(image: CVPixelBuffer, mask: CVPixelBuffer) throws -> LaMaFP16Output {
        let input_ = LaMaFP16Input(image: image, mask: mask)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        - parameters:
           - inputs: the inputs to the prediction as [LaMaFP16Input]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [LaMaFP16Output]
    */
    func predictions(inputs: [LaMaFP16Input], options: MLPredictionOptions = MLPredictionOptions()) throws -> [LaMaFP16Output] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [LaMaFP16Output] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  LaMaFP16Output(features: outProvider)
            results.append(result)
        }
        return results
    }
}
