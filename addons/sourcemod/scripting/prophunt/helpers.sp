/*
 * Copyright (C) 2021  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#define FLOAT_EPSILON	0.0001

any Min(any a, any b)
{
	return (a <= b) ? a : b;
}

any Max(any a, any b)
{
	return (a >= b) ? a : b;
}

any Clamp(any val, any min, any max)
{
	return Min(Max(val, min), max);
}

// Thanks to ficool2 for helping me with scary vector math
bool IntersectionLineAABBFast(const float[3] mins, const float[3] maxs, const float[3] start, const float[3] dir, float far)
{
	// Test each cardinal plane (X, Y and Z) in turn
	float near = 0.0;
	
	if (!CloseEnough(dir[0], 0.0, FLOAT_EPSILON))
	{
		float recipDir = 1.0 / dir[0];
		float t1 = (mins[0] - start[0]) * recipDir;
		float t2 = (maxs[0] - start[0]) * recipDir;
		
		// tNear tracks distance to intersect (enter) the AABB
		// tFar tracks the distance to exit the AABB
		if (t1 < t2)
			near = Max(t1, near), far = Min(t2, far);
		else // Swap t1 and t2
			near = Max(t2, near), far = Min(t1, far);
		
		if (near > far)
			return false; // Box is missed since we "exit" before entering it
	}
	else if (start[0] < mins[0] || start[0] > maxs[0])
	{
		// The ray can't possibly enter the box, abort
		return false;
	}
	
	if (!CloseEnough(dir[0], 0.0, FLOAT_EPSILON))
	{
		float recipDir = 1.0 / dir[1];
		float t1 = (mins[1] - start[1]) * recipDir;
		float t2 = (maxs[1] - start[1]) * recipDir;
		
		if (t1 < t2)
			near = Max(t1, near), far = Min(t2, far);
		else // Swap t1 and t2.
			near = Max(t2, near), far = Min(t1, far);
		
		if (near > far)
			return false; // Box is missed since we "exit" before entering it
	}
	else if (start[1] < mins[1] || start[1] > maxs[1])
	{
		// The ray can't possibly enter the box, abort
		return false;
	}
	
	// Ray is parallel to plane in question
	if (!CloseEnough(dir[2], 0.0, FLOAT_EPSILON))
	{
		float recipDir = 1.0 / dir[2];
		float t1 = (mins[2] - start[2]) * recipDir;
		float t2 = (maxs[2] - start[2]) * recipDir;
		
		if (t1 < t2)
			near = Max(t1, near), far = Min(t2, far);
		else // Swap t1 and t2.
			near = Max(t2, near), far = Min(t1, far);
	}
	else if (start[2] < mins[2] || start[2] > maxs[2])
	{
		// The ray can't possibly enter the box, abort
		return false;
	}
	
	return near <= far;
}

bool CloseEnough(float a, float b, float epsilon)
{
	return FloatAbs(a - b) <= epsilon;
}

bool IsValidBboxSize(const float[3] mins, const float[3] maxs)
{
	return ph_prop_min_size.FloatValue < GetVectorDistance(mins, maxs) < ph_prop_max_size.FloatValue;
}
