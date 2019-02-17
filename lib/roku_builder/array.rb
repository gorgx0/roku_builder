# ********** Copyright 2016 Viacom, Inc. Apache 2.0 **********

class ::Array
  def any_is_start?(full_string)
    each do |item|
      if full_string.start_with?(item)
        return true
      end
    end
    return false
  end
end
