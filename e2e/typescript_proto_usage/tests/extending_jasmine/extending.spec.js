import { ExampleMessage } from "../../extending_pb.mjs"

describe("Extending proto", () => {
  it("should have example message defined", () => {
    expect(new ExampleMessage()).not.toBeUndefined();
  });
});
