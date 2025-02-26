pragma circom 2.1.3;

/*
 * Calculates the Euclidean distance between two 3D points
 * Inputs:
 *   - point1[3]: First 3D point (x,y,z)
 *   - point2[3]: Second 3D point (x,y,z)
 *   - distance_cm: Public input for the claimed distance between points
 * Output:
 *   - out: 1 if the claimed distance is correct, 0 otherwise
 */

// Helper template to calculate square of a number
template Square() {
    signal input in;
    signal output out;
    
    out <== in * in;
}

// Template for calculating the square of the distance between two 3D points
template PointDistanceSquared() {
    // Private inputs - 3D coordinates (x,y,z) for each point
    signal input point1[3];
    signal input point2[3];
    
    // Output - squared distance 
    signal output distanceSquared;
    
    // Calculate differences between coordinates
    signal diff[3];
    for (var i = 0; i < 3; i++) {
        diff[i] <== point1[i] - point2[i];
    }
    
    // Square the differences
    component squarer[3];
    for (var i = 0; i < 3; i++) {
        squarer[i] = Square();
        squarer[i].in <== diff[i];
    }
    
    // Sum the squares to get the squared distance
    distanceSquared <== squarer[0].out + squarer[1].out + squarer[2].out;
}

// Main template for the ZK hotdog measurement 
template ZkHotdog() {
    // Private input signals
    signal input point1[3]; // First point (x,y,z)
    signal input point2[3]; // Second point (x,y,z)
    
    // Public input signal - the claimed distance in cm
    signal input distance_mm;
    
    // Calculate squared distance between points
    component distCalc = PointDistanceSquared();
    for (var i = 0; i < 3; i++) {
        distCalc.point1[i] <== point1[i];
        distCalc.point2[i] <== point2[i];
    }
    
    // The squared distance is available in distCalc.distanceSquared
    
    // Constraint: The claimed distance_cm squared times the scale must equal the calculated squared distance
    // This ensures that distance_cm = sqrt(distanceSquared)/sqrt(scale)
    distance_mm * distance_mm === distCalc.distanceSquared;

}

// Main component instantiation
component main {public [distance_mm]} = ZkHotdog();
