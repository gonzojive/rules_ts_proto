import { GreetingRequest, TopLevelEnumExample, RepeatedThing } from "../../greeting_pb.mjs"
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

  it("should have valid repeated fields", () => {
    const thing = new RepeatedThing().setChildThingsList(["x", "y"]);
    expect(thing.getChildThingsList()).toBe(["x", "y"]);
  });
});

describe("TopLevelEnumExample", () => {
  it("THINGY2 member should have value 2", () => {
    expect(TopLevelEnumExample.THINGY2).toBe(2);
  });
});
