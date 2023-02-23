import cv2
import numpy as np
import pytesseract
import copy
import os

def get_table_corners(corners):
    """Calculates the four corner points of the table based on the detected corners."""
    x_min, y_min = float('inf'), float('inf')
    x_max, y_max = 0, 0
    for corner in corners:
        x1, y1, x2, y2 = corner
        x_min = min(x_min, x1, x2)
        y_min = min(y_min, y1, y2)
        x_max = max(x_max, x1, x2)
        y_max = max(y_max, y1, y2)

    corner_points = [(x_min, y_min, x_min, y_min),  # top-left corner
                     (x_max, y_min, x_max, y_min),  # top-right corner
                     (x_max, y_max, x_max, y_max),  # bottom-right corner
                     (x_min, y_max, x_min, y_max)]  # bottom-left corner

    return corner_points

RES_RATIO = int(os.environ["RES_HIGH"]) / int(os.environ["RES_LOW"])

#def reduce_res(image):
#    # get the current resolution of the image
#    height, width, channels = image.shape
#
#    # calculate the new resolution based on 72 dpi
#    new_width = int(width / RES_RATIO)
#    new_height = int(height / RES_RATIO)
#
#    resized_img = cv2.resize(image, (new_width, new_height))
#    return resized_img
#
#def increase_res(image):
#    # get the current resolution of the image
#    height, width, channels = image.shape
#
#    # calculate the new resolution based on 72 dpi
#    new_width = int(width * RES_RATIO)
#    new_height = int(height * RES_RATIO)
#
#    resized_img = cv2.resize(image, (new_width, new_height))
#    return resized_img

def get_line_segments(gray):
    # blur the image to help detect blurry lines
    blurred = cv2.GaussianBlur(gray, (3, 3), 0)

    # detect edges using Canny edge detection
    edges = cv2.Canny(blurred, 40, 450)

    # apply morphological closing to connect broken lines and fill gaps
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    closed = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel)

    # detect line segments using HoughLinesP with higher resolution and smaller minimum line length
    lines = cv2.HoughLinesP(closed, rho=1, theta=np.pi / 180, threshold=40, minLineLength=100, maxLineGap=15)

    # separate line segments into horizontal and vertical
    horizontal_lines = []
    vertical_lines = []
    for line in lines:
        x1, y1, x2, y2 = line[0]
        if np.abs(y2 - y1) < np.abs(x2 - x1):
            # line segment is vertical
            vertical_lines.append(line)
        else:
            # line segment is horizontal
            horizontal_lines.append(line)

    return horizontal_lines, vertical_lines

def get_line_intersections(horizontal_lines, vertical_lines):
    # find intersections between horizontal and vertical lines
    intersections = []
    for hline in horizontal_lines:
        for vline in vertical_lines:
            x1, y1, x2, y2 = hline[0]
            x3, y3, x4, y4 = vline[0]
            denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
            if denom != 0:
                t1 = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / denom
                t2 = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / denom
                if 0 <= t1 <= 1 and 0 <= t2 <= 1:
                    x = int(x1 + t1 * (x2 - x1))
                    y = int(y1 + t1 * (y2 - y1))
                    intersections.append((x, y))

    return intersections

def intersecting_corners(intersections):
    # find corners of tables using intersections
    corners = []
    for i in range(len(intersections)):
        for j in range(i + 1, len(intersections)):
            xi, yi = intersections[i]
            xj, yj = intersections[j]
            if xi != xj and yi != yj:
                corners.append((xi, yi, xj, yj))

#    print(corners)
    return corners

def deduplicate_corners(corners):
    # Remove duplicate corners
    deduplicated = []
    for i in range(len(corners)):
        for j in range(i):
            # Manhattan distance
            distance = abs(corners[i][0] - corners[j][0]) + abs(corners[i][1] - corners[j][1])
            if distance < 20:
                break
        else:
            deduplicated.append(corners[i])
    return deduplicated

def add_missing_corners(corner_points, corners):
    # check if any corners are missing and add them to the corners list
    for point in corner_points:
        min_distance = float('inf')
        for corner in corners:
            # We can probably use manhattan distance instead of eucladian here
            distance = np.sqrt((corner[0] - point[0]) ** 2 + (corner[1] - point[1]) ** 2)
            if distance < min_distance:
                min_distance = distance
        if min_distance > 20:
            corners.append(point)
    return corners

def fill_missing_arr(point_l):
    # Find the maximum and minimum x and y values
    x_min = min(x for x, y in point_l)
    x_max = max(x for x, y in point_l)
    y_min = min(y for x, y in point_l)
    y_max = max(y for x, y in point_l)

    if np.isnan(x_min):
        x_min = np.nan_to_num(x_min)
    if np.isnan(x_max):
        x_max = np.nan_to_num(x_max)
    if np.isnan(y_min):
        y_min = np.nan_to_num(y_min)
    if np.isnan(y_max):
        y_max = np.nan_to_num(y_max)

    # Determine the number of rows and columns in the array
    num_cols = int((x_max - x_min + 20) // 20)
    num_rows = int((y_max - y_min + 20) // 20)

    # Initialize the array with None values
    arr = [[None for _ in range(num_cols)] for _ in range(num_rows)]

    # Fill in the array with the points
    for x, y in point_l:
        i = (y - y_min) // 20
        j = (x - x_min) // 20
        arr[i][j] = (x, y)

    # Remove empty rows and columns
    row_sums = [sum(1 for x in row if x is not None) for row in arr]
    col_sums = [sum(1 for row in arr if row[j] is not None) for j in range(num_cols)]
    non_empty_rows = [i for i, row_sum in enumerate(row_sums) if row_sum > 0]
    non_empty_cols = [j for j, col_sum in enumerate(col_sums) if col_sum > 0]
    arr = [[arr[i][j] for j in non_empty_cols] for i in non_empty_rows]

    x_averages = []
    for j in range(len(arr[0])):
        x_vals = [t[0] for t in [arr[i][j] for i in range(len(arr))] if t is not None]
        x_avg = sum(x_vals) // len(x_vals)
        x_averages.append(x_avg)

    y_averages = []
    for i in range(len(arr)):
        values = [t[1] for t in arr[i] if t is not None]
        if len(values) > 0:
            y_averages.append(sum(values) // len(values))
        else:
            y_averages.append(None)

    # Fill in missing values with the row or column average
    for i in range(len(arr)):
        for j in range(len(arr[0])):
            if arr[i][j] is None:
                x = x_averages[j]
                y = y_averages[i]
                if x is not None and y is not None:
                    arr[i][j] = (x, y)

    return arr

#def detect_table(content_b: bytes):
def detect_table(image):
    print('Inside detect_tables')

    # load image and convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # separate line segments into horizontal and vertical
    horizontal_lines, vertical_lines = get_line_segments(gray)
    print(f'horizontal count = {len(horizontal_lines)}, vertical count = {len(vertical_lines)}')

    # find intersections between horizontal and vertical lines
    intersections = get_line_intersections(horizontal_lines, vertical_lines)

    # filter out duplicate intersections
    intersections = list(set(intersections))
    print(f'intersections count = {len(intersections)}')

    # find corners of tables using intersections
    corners = intersecting_corners(intersections)
    print(f'corners count = {len(corners)}')

    # calculate the four corner points of the table
    corner_points = get_table_corners(corners)
    print(f'table corners count = {len(corner_points)}')

    # Remove duplicate corners
    corners =deduplicate_corners(corners)
    print(f'deduplicated corners count = {len(corners)}')

    # check if any corners are missing and add them to the corners list
    corners = add_missing_corners(corner_points, corners)
    print(f'added missing corners. Now corners count = {len(corners)}')

    # Get points
    point_l = []
    for corner in corners:
        point_l.append(corner[:2])

    arr = fill_missing_arr(point_l)
    print(f'added missing points. Now arr = {arr}')

    return corners, corner_points, arr, horizontal_lines, vertical_lines

def get_lowres_ouput(image_orig, arr, horizontal_lines, vertical_lines):

    # protect image data from modification
    image = copy.deepcopy(image_orig)
    # draw lines on image for visualization
    line_thickness = int(round(image.shape[0] / 500))  # set line thickness based on image size
    line_color = (0, 0, 255)  # set line color to red
    for line in horizontal_lines + vertical_lines:
        x1, y1, x2, y2 = line[0]
        cv2.line(image, (x1, y1), (x2, y2), line_color, line_thickness)

    newarr = []
    for i in range(len(arr)):
        for j in range(len(arr[0])):
            if arr[i][j] is not None:
                newarr.append(arr[i][j])

    # draw corners on original image
    corner_radius = int(round(image.shape[0] / 100))  # set corner radius based on image size
    corner_color = (0, 255, 0)  # set corner color to green
    for corner in newarr:
        x, y = corner
        cv2.circle(image, (x, y), corner_radius, corner_color, -1)

    # save output image
    _, buffer = cv2.imencode('.jpg', image)
    image_b = buffer.tobytes()

    return image_b

def get_ouput(image_orig, lowres_arr, horizontal_lines, vertical_lines):

    # protect image data from modification
    image = copy.deepcopy(image_orig)
    arr = [[(int(lowres_arr[i][j][0]*RES_RATIO), int(lowres_arr[i][j][1]*RES_RATIO)) for j in range(len(lowres_arr[i]))] for i in range(len(lowres_arr))]

    # draw lines on image for visualization
    line_thickness = int(round(image.shape[0] / 500))  # set line thickness based on image size
    line_color = (0, 0, 255)  # set line color to red
    for line in horizontal_lines + vertical_lines:
        x1, y1, x2, y2 = line[0]
        cv2.line(image, (int(x1*RES_RATIO), int(y1*RES_RATIO)), (int(x2*RES_RATIO), int(y2*RES_RATIO)), line_color, line_thickness)

    newarr = []
    for i in range(len(arr)):
        for j in range(len(arr[0])):
            if arr[i][j] is not None:
                newarr.append(arr[i][j])

    # draw corners on original image
    corner_radius = int(round(image.shape[0] / 100))  # set corner radius based on image size
    corner_color = (0, 255, 0)  # set corner color to green
    for corner in newarr:
        x, y = corner
        cv2.circle(image, (x, y), corner_radius, corner_color, -1)
    # save output image
    _, buffer = cv2.imencode('.jpg', image)
    image_b = buffer.tobytes()

    return image_b

def get_table_dim_list(lowres_arr):
    arr = [[(int(lowres_arr[i][j][0]*RES_RATIO), int(lowres_arr[i][j][1]*RES_RATIO)) for j in range(len(lowres_arr[i]))] for i in range(len(lowres_arr))]
    # Get table_2D
    table_dim_l = []
    table_dim = []
    for i in range(len(arr) - 1):
        row = []
        for j in range(len(arr[i]) - 1):
            cell = [arr[i][j], arr[i+1][j+1]]
#            row[j] = cell
            row.append(cell)
        table_dim.append(row)
        print('table_dimensions = ', table_dim[i])
    table_dim_l.append(table_dim)
    return table_dim_l

def text_in_bounding_box(cell, image):
    print(f'cell = {cell}')
    x0, y0, x1, y1 = cell

    # Extract the cell from the image
    cell_image = image[int(y0 * RES_RATIO):int(y1 * RES_RATIO), int(x0 * RES_RATIO):int(x1 * RES_RATIO)]
    print('paragraph dim: ', int(y0 * RES_RATIO), int(y1 * RES_RATIO), int(x0 * RES_RATIO), int(x1 * RES_RATIO))

    # Convert the cell image to grayscale
    gray = cv2.cvtColor(cell_image, cv2.COLOR_BGR2GRAY)

    # Apply thresholding to the cell image
    thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]

    # Apply dilation to the thresholded image
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2,2))
    dilate = cv2.dilate(thresh, kernel, iterations=2)

    # Extract text from the cell using PyTesseract
    text = pytesseract.image_to_string(dilate, config='--psm 6')

    # Print the text for this cell
    print(cell, text)
    return text

def jpg_in_bounding_box(cell, image):
    # Get the top-left and bottom-right corners of the cell
    print(f'image size = {image.shape}')
    x0, y0, x1, y1 = cell
    print(f'cell dim = {cell}')

    # Extract the cell from the image
    cell_image = image[y0:y1, x0:x1]

    return cell_image

def remove_bbox_from_image(image, corners_l):
    # Protect masked image data from modification
    masked_image = copy.copy(image)

    for corners in corners_l:
        min_c = min(corners)
        max_c = max(corners)

        # Create a binary mask for the table regions
        mask = np.zeros_like(masked_image)
        mask[int(min_c[1] * RES_RATIO): int(max_c[1] * RES_RATIO), int(min_c[0] * RES_RATIO): int(max_c[0] * RES_RATIO)] = 255
        mask = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY)

        # Apply the mask to the image
        masked_image = cv2.bitwise_and(masked_image, masked_image, mask=cv2.bitwise_not(mask))

    return masked_image

#def extract_text(img_content):
#    img_file = fitz.open(stream=img_content, filetype='jpg')
#    page = list(img_file.pages())[0]
#    pix = page.get_pixmap()
#
#    # Create a new document with a single page
#    doc = fitz.open()
#    page = doc.new_page()
#
#    # Draw the image onto the page
#    page.insert_image(fitz.Rect(0, 0, page.rect.width, page.rect.height), pixmap=pix)
#
#    textpage = page.get_textpage_ocr(flags=7, language='eng', dpi=600, full=True)
#
#    text = textpage.extractText()
#
#    return text
