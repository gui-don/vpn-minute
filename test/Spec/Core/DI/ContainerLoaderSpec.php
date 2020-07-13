<?php

namespace Spec\VPNMinute\Core\DI;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\DI\ContainerLoader;
use Symfony\Component\DependencyInjection\ContainerBuilder;

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
