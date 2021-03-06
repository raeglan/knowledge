#!/usr/bin/env python
# license removed for brevity
import rospy
import random
import math
from std_msgs.msg import String
from suturo_perception_msgs.msg import ObjectDetection
from Crypto.Random.random import randint
from time import sleep


def talker(**kwargs):
    types = 1
    objects = 1
    if 'types' in kwargs:
        types = kwargs['types']
    if 'objects' in kwargs:
        objects = kwargs['objects']
    #objects = 1 #test with multiple objects of same type not yet done
        
    names = ['cake', 'box', 'cylinder', 'sphere', 'cone', 'dropzone']
    types = min(types, len(names))
    data = {}
    
    print("testing with %d types and %d objects per type" %(types, objects))
    sleep(2)
    i = 1
    
    for type in range(0,types):
        for v in range(0,objects):
            name = "object" + str(i)
            data[name] = {\
                'name' : names[type],
                'position': {'x': float(randint(0,10)),
                             'y': float(randint(0,10)),
                             'z': float(randint(0,10))},
                'type': type,
                'width' : float(randint(1,5)),
                'height': float(randint(1,5)),
                'depth' : float(randint(1,5))}
            i += 1
    
    
    i = 0
    pub = rospy.Publisher('percepteros/object_detection', ObjectDetection, queue_size=10)
    rospy.init_node('dummy_objects', anonymous=True)
    rate = rospy.Rate(5) # 1hz
    
    while not rospy.is_shutdown():
        key = random.choice(data.keys())
        i += 1
        time = rospy.get_time()

        obj = ObjectDetection(name = data[key]['name'])
        obj.pose.header.stamp.secs = int(time)
        obj.pose.header.stamp.nsecs= int((time % 1)*math.pow(10, 9))
        obj.pose.header.seq = i
        obj.pose.header.frame_id = 'odom_combined' #'head_mount_kinect_rgb_optical_frame'
        obj.pose.pose.position.x = data[key]['position']['x']
        obj.pose.pose.position.y = data[key]['position']['y']
        obj.pose.pose.position.z = data[key]['position']['z']
        obj.pose.pose.orientation.x = 0.0 #data[name]['orientation']['x']
        obj.pose.pose.orientation.y = 0.0 #data[name]['orientation']['y']
        obj.pose.pose.orientation.z = 0.0 #data[name]['orientation']['z']
        obj.pose.pose.orientation.w = 1.0 #data[name]['orientation']['w']
        obj.type = data[key]['type']
        obj.width = data[key]['width']
        obj.height = data[key]['height']
        obj.depth = data[key]['depth']
        rospy.loginfo(obj)
        pub.publish(obj)
        rate.sleep()

if __name__ == '__main__':
    noTypes = input('How many types do you want?    ')
    noObj   = input('How many objects per type?    ')
    try:
        talker(types = noTypes, objects = noObj)
    except rospy.ROSInterruptException:
        pass