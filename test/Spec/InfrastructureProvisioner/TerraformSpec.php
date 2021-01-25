<?php

declare(strict_types=1);

namespace Spec\VPNMinute\InfrastructureProvisioner;

use PhpSpec\ObjectBehavior;
use VPNMinute\InfrastructureProvisioner\Terraform;

class TerraformSpec extends ObjectBehavior
{
    public function it_is_initializable()
    {
        $this->shouldHaveType(Terraform::class);
    }

    public function it_returns_its_name()
    {
        $this->getName()->shouldReturn('terraform');
    }
}
