defmodule EvercamMedia.MotionDetection.Lib do
  @on_load :init

  def init() do
    :erlang.load_nif("./priv_dir/lib_elixir_motiondetection", 0)
  end

  def compare(image1, image2) do
    {:ok, {width1, height1, bytes1}} = load(image1)
    {:ok, {_width2, _height2, bytes2}} = load(image2)

    # use this to parallel the process, and play with the quality and performance
    position = width1*height1*3 # end position for a process
    min_position = 0 # start position for a process in a binary list of pixesl {R,G,B}
    step = 2 # check each 2nd pixel
    minimum = 30 # change between previous and current image should be at least

    result = compare(bytes1, bytes2, position, min_position, step, minimum)
    motion_level = round(result * 100)

    motion_level
  end

  def load(image) do
    _load(image)
  end

  def compare(bytes1, bytes2, position, min_position, step, minimum) do
    _compare(bytes1, bytes2, position, min_position, step, minimum)
  end

  def _test(images_path) do
    "NIF library not loaded. Trying to call method `_load`. And to pass #{images_path}"
  end

  def _load(_Binary) do
    "NIF library not loaded. Trying to call method `_load`."
  end

  def _compare(_bytes1, _bytes2, _position, _min_position, _step, _min) do
    "NIF library not loaded. Trying to call method `_compare`."
  end
end
