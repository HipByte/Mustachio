class NSObject
  def after_delay(delay, &block)
    block.performSelector('call', withObject:nil, afterDelay:delay)
  end
end
