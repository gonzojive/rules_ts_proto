import { Ancestor1, GreetingRequest, TopLevelEnumExample, RepeatedThing } from "../../greeting_pb.mjs"
import { Position } from "../../location/location_pb.mjs"
//import { GreetingRequest } from "../../greeting_pb";

function say_hi() {
  return new GreetingRequest().setName("hello").getName();
}

describe("lib", () => {
  it("should say hello", () => {
    expect(say_hi()).toBe("hello");
  });

  it("should be serializable", () => {
    const request = new GreetingRequest().setName("hello");
    const requestRoundtripped = GreetingRequest.deserializeBinary(request.serializeBinary());
    expect(requestRoundtripped.getName()).toBe("hello");
  });

  it("sub types should be serializable", () => {
    const latitude = 42;
    const message = 'hello';
    const request = new GreetingRequest()
        .setOrigin(new Position().setLatitude(latitude))
        .setGreetingMessage(new GreetingRequest.Greeting().setMessage(message));
    const requestRoundtripped = GreetingRequest.deserializeBinary(request.serializeBinary());
    expect(requestRoundtripped.getOrigin().getLatitude()).toBe(latitude);
    expect(requestRoundtripped.getGreetingMessage().getMessage()).toBe(message);
  });

  it("sub-sub types should be serializable", () => {
    const input = new Ancestor1.Ancestor2.Ancestor3()
        .setValue("xyz");
    const inputRoundtripped = Ancestor1.Ancestor2.Ancestor3.deserializeBinary(
      input.serializeBinary());
    expect(input.getValue()).toBe("xyz");
    expect(inputRoundtripped.getValue()).toBe("xyz");
  });

  it("should be serializable with repeated fields", () => {
    const object = new RepeatedThing().setChildStringsList(["x", "y"]);
    const roundtripped = RepeatedThing.deserializeBinary(object.serializeBinary());
    expect(roundtripped.getChildStringsList()).toEqual(["x", "y"]);
  });

  it("should have valid repeated string fields", () => {
    const thing = new RepeatedThing().setChildStringsList(["x", "y"]);
    expect(thing.getChildStringsList()).toEqual(["x", "y"]);
  });

  it("should have valid repeated object fields", () => {
    const a = new Position().setLatitude(42);
    const b = new Position().setLatitude(43);
    const thing = new RepeatedThing().setChildPositionsList([a, b]);
    expect(thing.getChildPositionsList().map(x => x.getLatitude())).toEqual([42, 43]);
  });
});

describe("TopLevelEnumExample", () => {
  it("THINGY2 member should have value 2", () => {
    expect(TopLevelEnumExample.THINGY2).toBe(2);
  });
});
