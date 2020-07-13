<?php

use VPNMinute\Core\HelloWorld;
use VPNMinute\Core\DI\ContainerLoader;

require __DIR__ . '/vendor/autoload.php';

$containerLoader = new ContainerLoader();
$container = $containerLoader->load();

/**
 * @var HelloWorld
 */
$helloWorld = $container->get(HelloWorld::class);

$helloWorld->display();

