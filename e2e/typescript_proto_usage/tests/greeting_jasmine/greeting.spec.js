import { GreetingRequest, TopLevelEnumExample } from "../../greeting_pb.mjs"
//import { GreetingRequest } from "../../greeting_pb";

function say_hi() {
  return new GreetingRequest().setName("hello").getName();
}

describe("lib", () => {
  it("should say hello", () => {
    expect(say_hi()).toBe("hello");
  });

  it("should be serializable", () => {
    const request = new GreetingRequest();
    expect(request.serializeBinary()).toBe("non empty");
  });
});

describe("TopLevelEnumExample", () => {
  it("THINGY2 member should have value 2", () => {
    expect(TopLevelEnumExample.THINGY2).toBe(2);
  });
});
