<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\HelloWorld;

class HelloWorldSpec extends ObjectBehavior
{
    public function it_is_initializable()
    {
        $this->shouldHaveType(HelloWorld::class);
    }

    public function it_displays_hello_world()
    {
        $this->display();
    }
}
