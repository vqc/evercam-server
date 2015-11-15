defmodule EvercamMedia.ONVIFAccessPlugTest do
  use ExUnit.Case
  alias EvercamMedia.ONVIFAccessPlug
  
  test "build_parameters returns a proper xml fragment" do
    response = ONVIFAccessPlug.build_parameters(["ProfileToken=Profile_1", "StuffParameter=SomeStuff"])
    assert response == "<ProfileToken>Profile_1</ProfileToken><StuffParameter>SomeStuff</StuffParameter>"
  end
 
end
