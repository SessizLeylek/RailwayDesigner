package game

import rl "vendor:raylib"
import math "core:math"
import "core:fmt"


//$ CONSTANTS

    IDENTITY_MATRIX := rl.Matrix {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    }

//$ MESH AND MODEL RELATED STRUCTS AND PROCEDURES

    // Defines a circular arc
    Arc :: struct
    {
        angle : f32,
        startPoint, upVector : rl.Vector3,
    }

    // Returns the position of a point on arc given t = [0, 1]; 0 is the start point and 1 is the end point
    Arc_ReturnPoint :: proc(arc : Arc, t : f32) -> rl.Vector3
    {
        return rl.Vector3RotateByAxisAngle(arc.startPoint, arc.upVector, arc.angle * t * rl.DEG2RAD)
    }

    // Returns the radius of an arc
    Arc_Radius :: proc(arc: Arc) -> f32
    {
        return rl.Vector3Length(arc.startPoint)
    }

    // Returns the length of an arc
    Arc_Length :: proc(arc : Arc) -> f32
    {
        return Arc_Radius(arc) * 2 * rl.PI * (abs(arc.angle) / 360)
    }

    // Defines a line
    Line :: struct 
    {
        startPoint, endPoint : rl.Vector3,
    }

    
    CurvedTrack :: struct
    {
        arc : Arc,
        position : rl.Vector3,
        mesh : rl.Mesh,
    }

    // Creates and returns a curved track; manually alocates memory for the track
    Track_CreateFromArc :: proc(arc : Arc, position : rl.Vector3) -> ^CurvedTrack
    {
        newTrack := new(CurvedTrack)

        rectCount := max(1, i32(Arc_Length(arc)))
        fmt.println(rectCount)

        newTrack.mesh.vertexCount = rectCount * 6
        newTrack.mesh.triangleCount = rectCount * 2
            
        newTrack.mesh.vertices = make([^]f32, 18 * rectCount)  // 6 vertices for rect and 3 values for each vertex: x y z
        newTrack.mesh.texcoords = make([^]f32, 12 * rectCount)  // 6 vertices for rect and 2 values for each texture coordinates: x y
        
        // Creating the rects
        for i : i32 = 0; i < rectCount; i += 1
        {
            // Calculate points and normals of that points 
            point0 := Arc_ReturnPoint(arc, f32(i) / f32(rectCount))
            point1 := Arc_ReturnPoint(arc, f32(i + 1) / f32(rectCount))

                // If the angle is negative, the mesh is created upside down
                // So we swap the order of two points to prevent this
                if arc.angle < 0 do point0, point1 = point1, point0

            normal0 := rl.Vector3Normalize(point0) * 0.5
            normal1 := rl.Vector3Normalize(point1) * 0.5

            // Translate that points by the track position
            point0 += position
            point1 += position

            // triangle 1: lower left
            // point 1: lower right
            newTrack.mesh.vertices[18 * i] = point0.x - normal0.x
            newTrack.mesh.vertices[18 * i + 1] = point0.y - normal0.y
            newTrack.mesh.vertices[18 * i + 2] = point0.z - normal0.z
            newTrack.mesh.texcoords[12 * i] = 1
            newTrack.mesh.texcoords[12 * i + 1] = 0

            // point 2: lower left
            newTrack.mesh.vertices[18 * i + 3] = point0.x + normal0.x
            newTrack.mesh.vertices[18 * i + 4] = point0.y + normal0.y
            newTrack.mesh.vertices[18 * i + 5] = point0.z + normal0.z
            newTrack.mesh.texcoords[12 * i + 2] = 0
            newTrack.mesh.texcoords[12 * i + 3] = 0

            // point 2: upper left
            newTrack.mesh.vertices[18 * i + 6] = point1.x + normal1.x
            newTrack.mesh.vertices[18 * i + 7] = point1.y + normal1.y
            newTrack.mesh.vertices[18 * i + 8] = point1.z + normal1.z
            newTrack.mesh.texcoords[12 * i + 4] = 0
            newTrack.mesh.texcoords[12 * i + 5] = 1

            // triangle 2: upper right
            // point 1: lower right
            newTrack.mesh.vertices[18 * i + 9] = point0.x - normal0.x
            newTrack.mesh.vertices[18 * i + 10] = point0.y - normal0.y
            newTrack.mesh.vertices[18 * i + 11] = point0.z - normal0.z
            newTrack.mesh.texcoords[12 * i + 6] = 1
            newTrack.mesh.texcoords[12 * i + 7] = 0

            // point 2: upper left
            newTrack.mesh.vertices[18 * i + 12] = point1.x + normal1.x
            newTrack.mesh.vertices[18 * i + 13] = point1.y + normal1.y
            newTrack.mesh.vertices[18 * i + 14] = point1.z + normal1.z
            newTrack.mesh.texcoords[12 * i + 8] = 0
            newTrack.mesh.texcoords[12 * i + 9] = 1

            // point 2: upper right
            newTrack.mesh.vertices[18 * i + 15] = point1.x - normal1.x
            newTrack.mesh.vertices[18 * i + 16] = point1.y - normal1.y
            newTrack.mesh.vertices[18 * i + 17] = point1.z - normal1.z
            newTrack.mesh.texcoords[12 * i + 10] = 1
            newTrack.mesh.texcoords[12 * i + 11] = 1
        }

        rl.UploadMesh(&newTrack.mesh, false) // upload mesh to gpu

        newTrack.arc = arc
        newTrack.position = position

        return newTrack
    }


    // Updates the transform matrix of a model to make it look at given direction;
    // forward and up are normalized vectors
    Model_LookDirection :: proc(model : ^rl.Model, forward : rl.Vector3, up : rl.Vector3 = {0, 1, 0})
    {
        right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, up))
        upOrthogonal := rl.Vector3CrossProduct(right, forward)   // second cross product to make sure up is orthogonal

        // Remember that opengl world space is right-handed; this took me a day
        model.transform = {
            forward.x, upOrthogonal.x, right.x, 0,
            forward.y, upOrthogonal.y, right.y, 0,
            forward.z, upOrthogonal.z, right.z, 0,
            0, 0, 0, 1
        }
    }


//$ GAME VARIABLES AND OBJECTS

    // Camera
    camera : rl.Camera3D = {{1, 0, 0}, {0, 0, 0}, {0, 1, 0}, 90, rl.CameraProjection.PERSPECTIVE}
    camera_verticalAngle : f32 = 0.0
    camera_distance : f32 = 10.0
    camera_height : f32 = 5.0
    camera_speed :: 8

    // Game Entities


main :: proc()
{
    rl.SetConfigFlags(rl.ConfigFlags {.MSAA_4X_HINT})

    rl.InitWindow(1280, 720, "Railway Game Test")
    rl.SetTargetFPS(30)

    /*rl.SetWindowSize(1920, 1080)
    rl.SetWindowState(rl.ConfigFlags {.MSAA_4X_HINT, .FULLSCREEN_MODE})*/

    //> Object Setup

    testModel := rl.LoadModel("res/duck.glb")
    secondModel := rl.LoadModel("res/pointer.glb")

    ourTrack := Track_CreateFromArc({60, {0, 0, 5}, {0, 1, 0}}, {-10, 0, 10})

    for !rl.WindowShouldClose()
    {   
        // Calculating important variables
        cameraForwardVector := rl.Vector3Normalize(camera.target - camera.position)
        cameraRightVector := rl.Vector3Normalize(rl.Vector3CrossProduct(cameraForwardVector, camera.up))
        cameraUpVector := rl.Vector3CrossProduct(cameraRightVector, cameraForwardVector)
        
        // Test camera movement
        cameraSpeedMultiplier := rl.GetFrameTime() * camera_speed
        if rl.IsKeyDown(.D) do camera.target += {cameraRightVector.x, 0, cameraRightVector.z} * cameraSpeedMultiplier
        if rl.IsKeyDown(.A) do camera.target -= {cameraRightVector.x, 0, cameraRightVector.z} * cameraSpeedMultiplier
        if rl.IsKeyDown(.W) do camera.target += {cameraForwardVector.x, 0, cameraForwardVector.z} * cameraSpeedMultiplier
        if rl.IsKeyDown(.S) do camera.target -= {cameraForwardVector.x, 0, cameraForwardVector.z} * cameraSpeedMultiplier

        if rl.IsKeyDown(.SPACE) do camera_height += cameraSpeedMultiplier
        if rl.IsKeyDown(.LEFT_SHIFT) do camera_height -= cameraSpeedMultiplier
        if rl.IsKeyDown(.Q) do camera_verticalAngle += cameraSpeedMultiplier * 0.4
        if rl.IsKeyDown(.E) do camera_verticalAngle -= cameraSpeedMultiplier * 0.4

        Model_LookDirection(&secondModel, rl.Vector3Normalize(camera.target - [3]f32 {15, 0, -10}), {0, 1, 0})
        Model_LookDirection(&testModel, rl.Vector3RotateByAxisAngle({1, 0, 0}, {0, 1, 0}, f32(rl.GetTime())))

        // Reposition camera according to its angle and distance from the target
        camera.position = rl.Vector3RotateByAxisAngle({-camera_distance, camera_height, 0}, {0, 1, 0}, camera_verticalAngle) + camera.target

        //> Rendering Section

        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)

        rl.BeginMode3D(camera)

            rl.DrawModel(testModel, {8, 0, 0}, 1, rl.WHITE)
            rl.DrawModel(secondModel, {15, 0, -10}, 1, rl.BLUE)

            rl.DrawMesh(ourTrack.mesh, rl.LoadMaterialDefault(), IDENTITY_MATRIX)

            rl.DrawSphere(camera.target, 0.2, rl.BLACK)
            rl.DrawGrid(100, 1)

        rl.EndMode3D()

        // FOR TESTING
        when true 
        {
            rl.DrawFPS(10, 10)
            
            // Draw Axis Arrows
            axisArrowX_x := rl.Vector3DotProduct({1, 0, 0}, cameraRightVector)
            axisArrowX_y := rl.Vector3DotProduct({1, 0, 0}, cameraUpVector)
            axisArrowY_x := rl.Vector3DotProduct({0, 1, 0}, cameraRightVector)
            axisArrowY_y := rl.Vector3DotProduct({0, 1, 0}, cameraUpVector)
            axisArrowZ_x := rl.Vector3DotProduct({0, 0, 1}, cameraRightVector)
            axisArrowZ_y := rl.Vector3DotProduct({0, 0, 1}, cameraUpVector)

            // +y is downwards on the canvas, so we substract the y component instead of adding
            rl.DrawLine(70, 70, 70 + i32(axisArrowX_x * 50), 70 - i32(axisArrowX_y * 50), rl.RED)
            rl.DrawLine(70, 70, 70 + i32(axisArrowY_x * 50), 70 - i32(axisArrowY_y * 50), rl.GREEN)
            rl.DrawLine(70, 70, 70 + i32(axisArrowZ_x * 50), 70 - i32(axisArrowZ_y * 50), rl.BLUE)
        }

        rl.EndDrawing()
    }
}