class MustachioViewController < UIViewController
  def loadView
    @debug = false

    self.view = UIView.alloc.initWithFrame(UIScreen.mainScreen.applicationFrame)
    view.backgroundColor = UIColor.redColor if @debug

    @imageView = UIImageView.alloc.initWithFrame(view.bounds)
    @imageView.contentMode = UIViewContentModeScaleAspectFit
    @imageView.userInteractionEnabled = true
    view.addSubview(@imageView)

    toolbar = UIToolbar.new
    toolbar.barStyle = UIBarStyleBlack
    #toolbar.translucent = true

    # TODO weird one pixel offset, not thinking about this too much more right now
    toolbar.frame = CGRectMake(0, view.bounds.size.height-44+1, view.bounds.size.width, 44)
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin

    items = []
    items << toolbarItem(UIBarButtonSystemItemCamera, target:self, action:'presentImagePickerController:')
    if TWTweetComposeViewController.canSendTweet || @debug
      items << toolbarSpaceItem
      items << toolbarItem(UIBarButtonSystemItemAction, target:self, action:'tweetPhoto:')
    end
    items << toolbarSpaceItem
    items << toolbarItem(UIBarButtonSystemItemSave,   target:self, action:'savePhoto:')
    toolbar.items = items

    view.addSubview(toolbar)
  end

  def shouldAutorotateToInterfaceOrientation(orientation)
    orientation == UIInterfaceOrientationPortrait
  end

  def presentImagePickerController(sender)
    # TODO check that images can be loaded in some way.
    #UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypePhotoLibrary)
    #UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypeCamera)
    #UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypeSavedPhotosAlbum)

    imagePickerController = UIImagePickerController.new
    imagePickerController.delegate = self
    #imagePickerController.allowsEditing = true
    presentModalViewController(imagePickerController, animated:true)
  end

  def imagePickerController(imagePickerController, didFinishPickingMediaWithInfo:info)
    if image = info[UIImagePickerControllerEditedImage] || info[UIImagePickerControllerOriginalImage]
      @imageView.image = mustachify(image)
    end
    dismissModalViewControllerAnimated(true)
  end

  def tweetPhoto(sender)
    controller = TWTweetComposeViewController.new
    controller.addImage(@imageView.image)
    presentModalViewController(controller, animated:true)
  end

  def savePhoto(sender)
    puts "SAVE"
  end

  # TODO Currently we just render the layer of the image view, but this should
  # obviously change to completely render it in an offscreen context.
  def mustachify(image)
    size            = image.size
    imageView       = UIImageView.alloc.initWithFrame([[0, 0], size.to_a])
    imageView.image = image

    @detector ||= CIDetector.detectorOfType(CIDetectorTypeFace, context:nil, options: { CIDetectorAccuracy: CIDetectorAccuracyHigh })
    @detector.featuresInImage(CIImage.imageWithCGImage(image.CGImage)).each do |feature|
      # We need the mouth and eyes positions to determine where the mustache
      # should be added.
      next unless feature.hasMouthPosition and feature.hasLeftEyePosition and feature.hasRightEyePosition

      if @debug
        [feature.leftEyePosition,feature.rightEyePosition,feature.mouthPosition].each do |pt|
          v = UIView.alloc.initWithFrame CGRectMake(0, 0, 20, 20)
          v.backgroundColor = UIColor.greenColor.colorWithAlphaComponent(0.2)
          pt = CGPointApplyAffineTransform(pt, transform)
          v.center = pt
          imageView.addSubview(v)
        end
      end

      # Create the mustache view.
      mustacheView = UIImageView.alloc.init
      mustacheView.image = UIImage.imageNamed('mustache')
      mustacheView.contentMode = UIViewContentModeScaleAspectFit

      # Compute its location and size, based on the position of the eyes and
      # mouth. 
      w = feature.bounds.size.width
      h = feature.bounds.size.height / 5
      x = (feature.mouthPosition.x + (feature.leftEyePosition.x + feature.rightEyePosition.x) / 2) / 2 - w / 2
      y = feature.mouthPosition.y

      # CoreImage used a coordinate system which is flipped on the Y axis
      # compared to UIKit. Also, a UIImageView can return an image larger than
      # itself. To properly translate points, we use an affine transform.
      transform = CGAffineTransformMakeScale(1, -1)
      transform = CGAffineTransformTranslate(transform, 0, -size.height)
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

  private

  def toolbarSpaceItem
    toolbarItem(UIBarButtonSystemItemFlexibleSpace, target:nil, action:nil)
  end

  def toolbarItem(type, target:target, action:action)
    item = UIBarButtonItem.alloc.initWithBarButtonSystemItem(type, target:target, action:action)
    item.style = UIBarButtonItemStyleBordered if target
    item
  end
end
