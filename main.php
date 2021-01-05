<?php

declare(strict_types=1);

use VPNMinute\Core\DI\ContainerLoader;
use VPNMinute\Core\HelloWorld;

require __DIR__.'/vendor/autoload.php';

$containerLoader = new ContainerLoader();
$container = $containerLoader->load();

/**
 * @var HelloWorld
 */
$helloWorld = $container->get(HelloWorld::class);

$helloWorld->display();
