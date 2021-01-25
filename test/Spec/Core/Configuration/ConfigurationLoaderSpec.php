<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Configuration;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Configuration\ConfigurationLoader;
use VPNMinute\Core\Exception\ConfigurationException;
use VPNMinute\Core\Exception\IOException;

class ConfigurationLoaderSpec extends ObjectBehavior
{
    public const CONTENT = [
        'infrastructure_Provisioner' => self::CONTENT_INFRASTRUCTURE_Provisioner,
    ];

    public const CONTENT_INFRASTRUCTURE_Provisioner = [
        'enable' => [
            0 => 'aws',
        ],
    ];

    public function it_is_initializable()
    {
        $this->shouldHaveType(ConfigurationLoader::class);
    }

    // load

    public function it_throws_an_exception_when_config_file_path_does_not_exists()
    {
        $this->shouldThrow(IOException::class)->during('load', ['does_not_exists']);
    }

    public function it_throws_an_exception_when_config_file_is_not_valid_yaml()
    {
        $this->shouldThrow(IOException::class)->during('load', [__FILE__]);
    }

    public function it_loads_a_valid_configuration_file()
    {
        $this->load(__DIR__.'/../../../Features/config.yml')->shouldBeLike(self::CONTENT);
    }

    public function it_reads_multiple_times_but_only_loads_once()
    {
        // This is an incomplete test
        // As Yaml object is static and cannot be mocked, matching number of calls to parseYaml method is not possible.
        $this->load(__DIR__.'/../../../Features/config.yml')->shouldBeLike(self::CONTENT);
        $this->load(__DIR__.'/../../../Features/config.yml')->shouldBeLike(self::CONTENT);
    }

    // getInfrastructureProvisionerOptions

    public function it_throws_an_exception_when_infrastructure_Provisioners_key_is_missing()
    {
        $this->shouldThrow(ConfigurationException::class)->during('getInfrastructureProvisionerOptions', [__DIR__.'/../../../Features/config_error.yml']);
    }

    public function it_loads_specific_infrastructure_Provisioners_configuration()
    {
        $this->getInfrastructureProvisionerOptions(__DIR__.'/../../../Features/config.yml')->shouldBeLike(self::CONTENT_INFRASTRUCTURE_Provisioner);
    }
}
