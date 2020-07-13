<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\DI;

use PhpSpec\ObjectBehavior;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use VPNMinute\Core\DI\ContainerLoader;

class ContainerLoaderSpec extends ObjectBehavior
{
    public function it_is_initializable()
    {
        $this->shouldHaveType(ContainerLoader::class);
    }

    public function it_loads_services_and_return_a_container()
    {
        $this->load()->shouldReturnAnInstanceOf(ContainerBuilder::class);
    }
}
