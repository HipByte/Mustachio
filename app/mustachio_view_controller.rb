class MustachioViewController < UIViewController
  def loadView
    @debug = false

    self.view = UIView.alloc.initWithFrame(UIScreen.mainScreen.applicationFrame)

    @imageView = UIImageView.alloc.initWithFrame(view.bounds)
    @imageView.contentMode = UIViewContentModeScaleAspectFit
    view.addSubview(@imageView)

    toolbar = UIToolbar.new
    toolbar.barStyle = UIBarStyleBlack

    # TODO weird one pixel offset, not thinking about this too much more right now
    toolbar.frame = CGRectMake(0, view.bounds.size.height-44+1, view.bounds.size.width, 44)
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin

    if TWTweetComposeViewController.canSendTweet || @debug
      @tweetButton = toolbarItem(UIBarButtonSystemItemAction, target:self, action:'tweetPhoto:')
    end
    toolbar.items = [
      @imagePickerButton = toolbarItem(UIBarButtonSystemItemCamera, target:self, action:'presentImagePickerController:'),
      toolbarSpaceItem,
      @tweetButton,
      toolbarSpaceItem,
      @saveButton = toolbarItem(UIBarButtonSystemItemSave, target:self, action:'savePhoto:')
    ].compact

    self.image = nil

    view.addSubview(toolbar)
  end

  def image=(image)
    image = mustachify(image) if image
    @imageView.image = image
    @saveButton.enabled = !image.nil?
    @tweetButton.enabled = !image.nil? if @tweetButton
    image
  end

  def shouldAutorotateToInterfaceOrientation(orientation)
    orientation == UIInterfaceOrientationPortrait
  end

  def presentImagePickerControllerForSourceType(sourceType)
    imagePickerController = UIImagePickerController.new
    imagePickerController.delegate = self
    imagePickerController.sourceType = sourceType
    imagePickerController.allowsEditing = true
    presentModalViewController(imagePickerController, animated:true)
  end

  def presentImagePickerController(sender)
    sources = []
    sources << :library if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypePhotoLibrary)
    sources << :saved   if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypeSavedPhotosAlbum)
    sources << :camera  if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypeCamera) || @debug

    case sources
    when [:library]
      presentImagePickerControllerForSourceType(UIImagePickerControllerSourceTypePhotoLibrary)
    when [:saved]
      presentImagePickerControllerForSourceType(UIImagePickerControllerSourceTypeSavedPhotosAlbum)
    when [:library, :saved]
      presentImagePickerControllerForSourceType(UIImagePickerControllerSourceTypePhotoLibrary | UIImagePickerControllerSourceTypeSavedPhotosAlbum)
    when [:camera]
      presentImagePickerControllerForSourceType(UIImagePickerControllerSourceTypeCamera)
    else
      if !sources.empty?
        sheet = UIActionSheet.alloc.initWithTitle(nil,
                                         delegate:self,
                                cancelButtonTitle:nil,
                           destructiveButtonTitle:nil,
                                otherButtonTitles:nil)
                                # BUG: using this on RM only works once, crashes on the second time
                                #otherButtonTitles:'Take Photo', 'Choose From Library')
        sheet.addButtonWithTitle('Take Photo')
        sheet.addButtonWithTitle('Choose From Library')
        sheet.cancelButtonIndex = sheet.addButtonWithTitle('Cancel')
        sheet.showFromBarButtonItem(@imagePickerButton, animated:true)
      else
        UIAlertView.alloc.initWithTitle("So Sorry…",
                                message:"Unable to access your photo library or camera.",
                               delegate:nil,
                      cancelButtonTitle:"OK",
                      otherButtonTitles:nil).show
      end
    end
  end

  def actionSheet(sheet, didDismissWithButtonIndex:buttonIndex)
    case buttonIndex
    when 0
      presentImagePickerControllerForSourceType(UIImagePickerControllerSourceTypeCamera)
    when 1
      sourceType = 0
      if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypePhotoLibrary)
        sourceType |= UIImagePickerControllerSourceTypePhotoLibrary
      end
      if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypeSavedPhotosAlbum)
        sourceType |= UIImagePickerControllerSourceTypeSavedPhotosAlbum
      end
      presentImagePickerControllerForSourceType(sourceType)
    end
  end

  def imagePickerController(imagePickerController, didFinishPickingMediaWithInfo:info)
    self.image = info[UIImagePickerControllerEditedImage] || info[UIImagePickerControllerOriginalImage]
    dismissModalViewControllerAnimated(true)
  end

  def tweetPhoto(sender)
    controller = TWTweetComposeViewController.new
    controller.addImage(@imageView.image)
    controller.completionHandler = lambda do |result|
      case result
      when TWTweetComposeViewControllerResultDone
        puts "Tweet posted successfully."
      when TWTweetComposeViewControllerResultCancelled
        puts "Tweet was cancelled, or an error occurred."
      end
    end
    presentModalViewController(controller, animated:true)
  end

  def savePhoto(sender)
    enableButtons(false)
    # Enable to trigger error.
    # return UIImageWriteToSavedPhotosAlbum(nil, self, 'image:didFinishSavingWithError:contextInfo:', nil)
    UIImageWriteToSavedPhotosAlbum(@imageView.image, self, 'image:didFinishSavingWithError:contextInfo:', nil)
  end

  def image(image, didFinishSavingWithError:error, contextInfo:info)
    if error
      enableButtons(true)
      UIAlertView.alloc.initWithTitle("So Sorry…",
                              message:error.localizedDescription,
                             delegate:nil,
                    cancelButtonTitle:"OK",
                    otherButtonTitles:nil).show
    else
      presentImagePickerController(self)
      # Prettier
      after_delay 0.2 do
        enableButtons(true)
      end
    end
  end

  private

  def enableButtons(enabled)
    @imagePickerButton.enabled = @saveButton.enabled = enabled
    @tweetButton.enabled = enabled if @tweetButton
  end

  def toolbarSpaceItem
    toolbarItem(UIBarButtonSystemItemFlexibleSpace, target:nil, action:nil)
  end

  def toolbarItem(type, target:target, action:action)
    item = UIBarButtonItem.alloc.initWithBarButtonSystemItem(type, target:target, action:action)
    item.style = UIBarButtonItemStyleBordered if target
    item
  end

  def mustacheImage
    today = NSCalendar.currentCalendar.components(NSDayCalendarUnit | NSMonthCalendarUnit, fromDate:NSDate.date)
    if @debug || (4 === today.month && (29..30) === today.day)
      UIImage.imageNamed('mustache-orange.png')
    else
      UIImage.imageNamed('mustache.png')
    end
  end

  # TODO Currently we just render the layer of the image view, but this should
  # obviously change to completely render it in an offscreen context.
  def mustachify(image)
    size            = image.size
    imageView       = UIImageView.alloc.initWithFrame([[0, 0], size.to_a])
    imageView.image = image

    @detector ||= CIDetector.detectorOfType(CIDetectorTypeFace, context:nil, options: { CIDetectorAccuracy: CIDetectorAccuracyHigh })
    features = @detector.featuresInImage(CIImage.imageWithCGImage(image.CGImage))

    if features.empty?
      UIAlertView.alloc.initWithTitle("So Sorry…",
                              message:"Unable to locate the required facial features. Cropping the image might help.",
                             delegate:nil,
                    cancelButtonTitle:"OK",
                    otherButtonTitles:nil).show
      return image
    end

    # CoreImage used a coordinate system which is flipped on the Y axis
    # compared to UIKit. Also, a UIImageView can return an image larger than
    # itself. To properly translate points, we use an affine transform.
    transform = CGAffineTransformMakeScale(1, -1)
    transform = CGAffineTransformTranslate(transform, 0, -size.height)

    features.each do |feature|
      # We need the mouth and eyes positions to determine where the mustache
      # should be added.
      next unless feature.hasMouthPosition and feature.hasLeftEyePosition and feature.hasRightEyePosition

      if @debug
        [feature.leftEyePosition,feature.rightEyePosition,feature.mouthPosition].each do |pt|
          v = UIView.alloc.initWithFrame(CGRectMake(0, 0, 20, 20))
          v.backgroundColor = UIColor.greenColor.colorWithAlphaComponent(0.2)
          pt = CGPointApplyAffineTransform(pt, transform)
          v.center = pt
          imageView.addSubview(v)
        end
      end

      # Create the mustache view.
      mustacheView = UIImageView.alloc.init
      mustacheView.image = mustacheImage
      mustacheView.contentMode = UIViewContentModeScaleAspectFit

      # Compute its location and size, based on the position of the eyes and
      # mouth. 
      w = feature.bounds.size.width
      h = feature.bounds.size.height / 5
      x = (feature.mouthPosition.x + (feature.leftEyePosition.x + feature.rightEyePosition.x) / 2) / 2 - w / 2
      y = feature.mouthPosition.y
      mustacheView.frame = CGRectApplyAffineTransform([[x, y], [w, h]], transform)

      # Apply a rotation on the mustache, based on the face inclination.
      mustacheAngle = Math.atan2(feature.leftEyePosition.x - feature.rightEyePosition.x,
                                 feature.leftEyePosition.y - feature.rightEyePosition.y) + Math::PI/2
      mustacheView.transform = CGAffineTransformMakeRotation(mustacheAngle)

      imageView.addSubview(mustacheView)
    end

    UIGraphicsBeginImageContext(size)
    imageView.layer.renderInContext(UIGraphicsGetCurrentContext())
    output = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    output
  end
end
