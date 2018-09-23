/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import SwiftyJSON
import Alamofire

class ViewController: UIViewController {
  
  // MARK: - IBOutlets
  @IBOutlet var takePictureButton: UIButton!
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var progressView: UIProgressView!
  @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
  
  // MARK: - Properties
  private var tags: [String]?
  private var colors: [PhotoColor]?
  
  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if !UIImagePickerController.isSourceTypeAvailable(.camera) {
      takePictureButton.setTitle("Select Photo", for: .normal)
    }
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    imageView.image = nil
  }
  
  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    
    if segue.identifier == "ShowResults",
      let controller = segue.destination as? TagsColorsViewController {
      controller.tags = tags
      controller.colors = colors
    }
  }
  
  // MARK: - IBActions
  @IBAction func takePicture(_ sender: UIButton) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.allowsEditing = false
    
    if UIImagePickerController.isSourceTypeAvailable(.camera) {
      picker.sourceType = .camera
    } else {
      picker.sourceType = .photoLibrary
      picker.modalPresentationStyle = .fullScreen
    }
    
    present(picker, animated: true)
  }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    // Local variable inserted by Swift 4.2 migrator.
    let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
    
    guard let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage else {
      print("Info did not have the required UIImage for the Original Image")
      dismiss(animated: true)
      return
    }
    
    imageView.image = image
    
    // MARK: - Codes Added after
    // 1. Hide the upload button, and show the progress view and activity view.
    takePictureButton.isHidden = true
    progressView.progress = 0.0
    progressView.isHidden = false
    activityIndicatorView.startAnimating()
    
    upload(image: image,
           progressCompletion: { [weak self] percent in
            // 2 While the file uploads, you call the progress handler with an updated percent. This updates the progress indicator of the progress bar.
            self?.progressView.setProgress(percent, animated: true)
      },
           completion: { [weak self] tags, colors in
            // 3 The completion handler executes when the upload finishes. This sets the controls back to their original state.
            self?.takePictureButton.isHidden = false // Show again.
            self?.progressView.isHidden = true
            self?.activityIndicatorView.stopAnimating()
            
            self?.tags = tags
            self?.colors = colors
            
            // 4 Finally the Storyboard advances to the results screen when the upload completes, successfully or not. The user interface doesn’t change based on the error condition.
            self?.performSegue(withIdentifier: "ShowResults", sender: self)
    })
    
    dismiss(animated: true)
  }
}

extension ViewController {
  func upload(image: UIImage,
              progressCompletion: @escaping (_ percent: Float) -> Void,
              completion: @escaping (_ tags: [String]?, _ colors: [PhotoColor]?) -> Void) {
    
    // 1 The image that’s being uploaded needs to be converted to a Data instance.
    guard let imageData = image.jpegData(compressionQuality: 0.5) else {
      //    guard let imageData = UIImageJPEGRepresentation(image, 0.5) else {
      print("Could not get JPEG representation of UIImage")
      return
    }
    
    // 2 Here you convert the JPEG data blob (imageData) into a MIME multipart request to send to the Imagga content endpoint.
    Alamofire.upload(
      multipartFormData: { multipartFormData in
        multipartFormData.append(imageData,
                                 withName: "imagefile",
                                 fileName: "image.jpg",
                                 mimeType: "image/jpeg")
        
    }, to: "http://api.imagga.com/v1/content",
      headers: ["Authorization": "Basic YWNjXzUwMThkMmI5YjUyNmQ2Zjo3ODVjZjg2YWMxYmIwOTdjYjAyZGI3YTEzZjRlM2YwZg=="],
      encodingCompletion: { encodingResult in
        // 0 Every response has a Result enum with a value and type. Using automatic validation, the result is considered a success when it returns a valid HTTP Code between 200 and 299 and the Content Type is of a valid type specified in the Accept HTTP header field.
        switch encodingResult {
        case .success(let upload, _, _):
          upload.uploadProgress { progress in
            progressCompletion(Float(progress.fractionCompleted))
          }
          upload.validate()
          upload.responseJSON { response in
            // 1 Check that the upload was successful, and the result has a value; if not, print the error and call the completion handler.
            guard response.result.isSuccess,
              let value = response.result.value else {
                print("Error while uploading file: \(String(describing: response.result.error))")
                completion(nil, nil)
                return
            }
            
            // 2 Using SwiftyJSON, retrieve the firstFileID from the response.
            let firstFileID = JSON(value)["uploaded"][0]["id"].stringValue
            print("Content uploaded with ID: \(firstFileID)")
            
            //3 Call the completion handler to update the UI. At this point, you don’t have any downloaded tags or colors, so simply call this with no data.
            completion(nil, nil)
            
          }
          
        case .failure(let encodingError):
          print(encodingError)
        }
    })
  }
  
  func downloadTags(contentID: String, completion: @escaping ([String]?) -> Void) {
    // 1 Perform an HTTP GET request against the tagging endpoint, sending the URL parameter content with the ID you received after the upload. Again, be sure to replace Basic xxx with your actual authorization header.
    Alamofire.request("http://api.imagga.com/v1/tagging",
                      parameters: ["content": contentID],
                      headers: ["Authorization": "Basic YWNjXzUwMThkMmI5YjUyNmQ2Zjo3ODVjZjg2YWMxYmIwOTdjYjAyZGI3YTEzZjRlM2YwZg=="])
      
      // 2 Check that the response was successful, and the result has a value; if not, print the error and call the completion handler.
      .responseJSON { response in
        guard response.result.isSuccess,
          let value = response.result.value else {
            print("Error while fetching tags: \(String(describing: response.result.error))")
            completion(nil)
            return
        }
        
        // 3 Using SwiftyJSON, retrieve the raw tags array from the response. Iterate over each dictionary object in the tags array, retrieving the value associated with the tag key.
        let tags = JSON(value)["results"][0]["tags"].array?.map { json in
          json["tag"].stringValue
        }
        
        // 4 Call the completion handler passing in the tags received from the service.
        completion(tags)
    }
  }
  
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
  return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
  return input.rawValue
}
