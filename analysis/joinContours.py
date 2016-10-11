import cv2
import numpy as np
from scipy.spatial import distance as dist

def threshold(imgPath):
    kernel = np.ones((5,5),np.uint8)
  
    img = cv2.imread(imgPath,0)
    img = cv2.medianBlur(img,17)

    th = cv2.adaptiveThreshold(img,255,cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY,15,2)
    th = cv2.morphologyEx(th, cv2.MORPH_OPEN, kernel, iterations = 2)
    th = cv2.bitwise_not(th)
    return (img, th)        



#http://dsp.stackexchange.com/questions/2564/opencv-c-connect-nearby-contours-based-on-distance-between-them
def find_if_close(cnt1,cnt2):
    D = dist.cdist(np.squeeze(cnt1), np.squeeze(cnt2))
    if np.amin(D) < 50:
        return True
    else:
        return False
    


#img = cv2.imread('/home/gabe/Pictures/RoKEh.jpg')
#gray = cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
img,thresh = threshold("/mnt/4TBraid04/imagesets04/20160902_vibassay_set11/dl1472969895_6_5_0/imgseries_h264.AVI_2fps.AVI_27_55_after.jpg")
#contours,hier = cv2.findContours(thresh,cv2.RETR_EXTERNAL,2)
cv2.namedWindow("Threhold", cv2.WINDOW_NORMAL)
cv2.imshow("Image", thresh)
cv2.waitKey(0) 

LENGTH = len(contours)
status = np.zeros((LENGTH,1))

for i,cnt1 in enumerate(contours):
    x = i    
    if i != LENGTH-1:
        for j,cnt2 in enumerate(contours[i+1:]):
            x = x+1
            close = find_if_close(cnt1,cnt2)
            if close == True:
                val = min(status[i],status[x])
                status[x] = status[i] = val
            else:
                if status[x]==status[i]:
                    status[x] = i+1

unified = []
maximum = int(status.max())+1
for i in xrange(maximum):
    pos = np.where(status==i)[0]
    if pos.size != 0:
        cont = np.vstack(contours[i] for i in pos)
        hull = cv2.convexHull(cont)
        unified.append(hull)

cv2.drawContours(img,unified,-1,(0,255,0),2)
cv2.drawContours(thresh,unified,-1,255,-1)

#cv2.namedWindow("Image", cv2.WINDOW_NORMAL)
#cv2.imshow("Image", img)
#cv2.waitKey(0)    
#cv2.namedWindow("Image", cv2.WINDOW_NORMAL)
#cv2.imshow("Image", thresh)
#cv2.waitKey(0)  