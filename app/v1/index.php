<?php
$ip = $_SERVER['SERVER_ADDR'] ?? gethostbyname(gethostname());
?>
<!DOCTYPE html>
<html>
<head>
  <title>Streamline v1</title>
  <style>
    body { font-family: Arial; background: #ffffff; padding: 40px; }
    .box { padding: 20px; border: 1px solid #ddd; width: 400px; }
  </style>
</head>
<body>
  <div class="box">
    <h2>Welcome to Streamline - v1</h2>
    <p><b>Server IP:</b> <?php echo $ip; ?></p>
  </div>
</body>
</html>
