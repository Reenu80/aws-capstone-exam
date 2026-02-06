<?php
$ip = $_SERVER['SERVER_ADDR'] ?? gethostbyname(gethostname());
?>
<!DOCTYPE html>
<html>
<head>
  <title>StreamLine v2</title>
  <style>
    body { font-family: Arial; background: #dff7ff; padding: 40px; }
    .box { padding: 20px; border: 2px solid #0088cc; width: 450px; border-radius: 10px; }
  </style>
</head>
<body>
  <div class="box">
    <h2>Welcome to StreamLine - v2 [New Feature]</h2>
    <p><b>Server IP:</b> <?php echo $ip; ?></p>
  </div>
</body>
</html>
