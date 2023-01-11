//import { GreetingRequest } from "../../greeting_pb.js"
import { GreetingRequest } from "../../greeting_pb.mjs"

function say_hi() {
    return new GreetingRequest().setGreeting("hello").getGreeting();
}

describe("lib", () => {
    it("should say hi", () => {
        expect(say_hi()).toBe("hi");
    })  
})
