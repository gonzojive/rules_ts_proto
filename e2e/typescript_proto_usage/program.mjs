//import { GreetingRequest } from "./greeting_pb.mjs";
import { Position } from "./location/location_pb.mjs";

const pos = new Position();
pos.setLatitude(42.42);
console.log("request.latitude = %s", pos.getLatitude());
