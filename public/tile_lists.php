<!DOCTYPE html>
<html>
<head>
  <title>Tile Lists</title>
  <style>
      body > div {
          width: 100%;
          height: 60vw;
          display: flex;
          flex-direction: column;
          justify-content: space-between;
      }

      body > div > div {
          flex-grow: 2;
          display: flex;
          flex-direction: row;
          justify-content: space-between;
      }

      body > div > div > a {
          flex-grow: 2;
          /*border: 1px solid #999;*/
          font-size: 60%;
      }
  </style>
<body style="margin:0; padding: 0">
<?php
$drop = $_GET['drop'] ?? null;
if ($drop !== null) {
  $file = "../" . ($_GET['l'] ?? '');

//  echo $file . ': ' . $drop . ' |';
  $tiles = explode("\n", file_get_contents($file));
//  echo count($tiles);
  $tiles = array_filter(
    $tiles,
    function($tile) use ($drop) {
      return $tile !== $drop;
    }
  );
//  echo '#' . count($tiles);
  file_put_contents($file, implode("\n", $tiles));
}

$add = $_GET['add'] ?? null;
if ($add !== null) {
  $file = "../" . ($_GET['l'] ?? '');

  $tiles = explode("\n", file_get_contents($file));
  $tiles = [...$tiles, $add];
  sort($tiles, SORT_NUMERIC);
  $tiles = array_unique($tiles);
  file_put_contents($file, implode("\n", $tiles));
}


$files = glob("../*_tile_list");

$tiles = [];
$tileLists = [];
foreach ($files as $file) {
  $fileName = basename($file);
  if ($fileName == 'test_tile_list') {
    continue;
  }

  $tile_list = file_get_contents($file);
  foreach (explode("\n", $tile_list) as $tile) {
    $tiles[$tile] = [...($tiles[$tile] ?? []), $fileName];
    if (!in_array($fileName, $tileLists)) {
      $tileLists[] = $fileName;
    }
  }
}
?>
<legend>
  <?php
  echo '<a href="?l=ALL">ALL</a> | ';
  foreach ($tileLists as $tileList) {
    echo '<a href="?' . http_build_query(['l' => $tileList]) . '">' . $tileList . '</a> | ';
  }
  ?>
  <button onclick="doDropHrefs()">Drop</button>
  <a href="?<?= http_build_query(['l' => $_GET['l'] ?? null, 'addMode' => 1]) ?>">ADD</a>
</legend>
<div>
  <?php
  //    var_dump($tileLists);
  for ($lat = 90; $lat >= -90; $lat--) {
    echo '<div>';
    for ($lon = -180; $lon <= 180; $lon++) {
      $tile = sprintf('%+03d%+04d', $lat, $lon) . '.dsf';

      $color = '';
      $link = '';
      if (isset($tiles[$tile])) {
        $color = '#999';
        if (count($tiles[$tile]) > 1) {
          $color = '#444';
        }
      }
//      if ($_GET['l'] == 'ALL') {
//        if (isset($tiles[$tile])) {
//          $color = 'green';
//          if (count($tiles[$tile]) > 1) {
//            $color = 'red';
//          }
//        }
      if (in_array($_GET['l'] ?? null, $tiles[$tile] ?? [])) {
        $color = 'green';
        if (count($tiles[$tile] ?? []) > 1) {
          $color = 'red';
          if ($_GET['addMode'] ?? null) {
          } else {
            $link = 'href="?' . http_build_query(['l' => $_GET['l'], 'drop' => $tile]) . '"';
          }
        }
      } else {
          if (isset($tiles[$tile]) && ($_GET['addMode'] ?? null) && ($_GET['l'] ?? null)) {
            $link = 'href="?' . http_build_query(['addMode' => 1, 'l' => $_GET['l'] ?? null, 'add' => $tile]) . '"';
          }
      }

      echo '
      <a ' . $link . '
      style="background: ' . $color . '"
      >' . '</a>
    ';
    }
    echo '</div>';
  }
  ?>
</div>
<script>
  const tiles = document.querySelectorAll('div a');
  const dropHrefs = [];

  tiles.forEach(tile => {
    tile.addEventListener('mouseover', (e) => {
      e.preventDefault()
      if (e.target.href && e.ctrlKey) {
        e.preventDefault();
        dropHrefs.push({el: e.target, href: e.target.href});
        e.target.removeAttribute('href');
        e.target.style.background = 'blue';
      }
    });
  });

  function doDropHrefs() {
    if (dropHrefs.length === 0) {
      return;
    }

    const drop = dropHrefs.shift()
    fetch(drop.href)
      .then(
        response => {
          if (response.ok) {
            drop.el.style.background = '#999';
          } else {
            drop.el.style.background = 'maroon';
          }
          
          doDropHrefs()
        }
      )
  }
</script>

</body>
</html>
